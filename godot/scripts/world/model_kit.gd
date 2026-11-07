class_name ModelKit
## Models made in Blender (tools/blender, docs/MODELS.md): loads a .glb and gives it the game's own look.
## A material named wh_<kind>_<rrggbb> becomes the Palette material of that kind and colour (the same wrapped light,
## rim and painted detail as everything built in code), multiplied by the model's vertex colours, which carry the
## ambient occlusion and colour variation baked in Blender. Not used by the game yet: the model lab places them for
## screenshots (place_lab, --models=res://tests/model_lab.json).

## Blender material kind -> Palette detail texture. Kinds whose detail is modelled (each stone, brick and tile is its
## own piece) get the faint mottle rather than a painted pattern on top of the real one.
const KINDS := {"plaster": "plaster", "stone": "mottle", "brick": "mottle", "wood": "wood", "roof": "mottle",
	"leaf": "mottle", "iron": "smooth", "glass": "smooth", "metal": "smooth", "paint": "smooth", "flower": "smooth",
	"fabric": "fabric", "skin": "smooth", "hair": "smooth", "eye": "smooth"}

static var _mats := {}
static var look := {}
static var _tex := {}

const PBR_TEX := {
	"plaster": ["plaster", 1.4, 2.2, true], "stone": ["stone", 0.9, 1.6, true], "brick": ["clay", 0.6, 1.2, true],
	"roof": ["clay", 0.7, 1.0, true], "wood": ["wood", 1.2, 0.8, true], "paving": ["paving", 4.0, 1.0, false],
	"knit": ["knit", 0.1, 2.6, true], "denim": ["denim", 0.14, 1.6, true], "leather": ["leather", 0.2, 1.4, true],
	"wool": ["wool", 0.14, 2.2, true]}
const PBR_PLAIN := {"iron": [0.42, 0.55], "metal": [0.36, 0.6], "glass": [0.05, 0.0], "paint": [0.72, 0.0],
	"flower": [0.62, 0.0], "leaf": [0.58, 0.0], "eye": [0.2, 0.0], "skin": [0.52, 0.0], "hair": [0.7, 0.0]}
const NEUTRAL_GAIN := 1.18
const MIX := {"paving": "blender", "plaster": "blender", "knit": "blender", "denim": "blender",
	"stone": "cc0", "wood": "cc0", "clay": "cc0", "leather": "cc0", "wool": "cc0"}

static func texture_set(material: String, textures: String) -> String:
	return String(MIX.get(material, "cc0")) if textures == "mix" else textures

const WET_PAVING := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D puddle_tex : filter_linear_mipmap, repeat_enable;
uniform float tile = 4.0;
uniform float wet = 1.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wpos.xz / tile;
	float p = smoothstep(0.56, 0.63, texture(puddle_tex, wpos.xz / 7.0).r) * wet;
	vec3 alb = texture(albedo_tex, uv).rgb * COLOR.rgb;
	ALBEDO = alb * mix(1.0, 0.6, wet) * mix(1.0, 0.72, p);
	ROUGHNESS = mix(mix(texture(rough_tex, uv).r, 0.3, wet), 0.02, p);
	NORMAL_MAP = mix(texture(normal_tex, uv).rgb, vec3(0.5, 0.5, 1.0), p);
	SPECULAR = 0.5;
}
"""

## Parses "wh_<kind>_<rrggbb>" (Godot may add a suffix to a duplicate name): {kind, color}, or {} if it isn't one.
static func parse(material_name: String) -> Dictionary:
	if not material_name.begins_with("wh_"): return {}
	var parts := material_name.split("_")
	if parts.size() < 3 or not parts[2].substr(0, 6).is_valid_hex_number(): return {}
	return {"kind": parts[1], "color": Color("#" + parts[2].substr(0, 6))}

## The game's material for a Blender material name; `recolor` swaps colours ({"d8a557": "e3c3a8"}), so one house
## can come in several plasters.
static func material_for(material_name: String, recolor: Dictionary = {}) -> Material:
	var p := parse(material_name)
	if p.is_empty(): return null
	var hex: String = (p.color as Color).to_html(false)
	hex = String(recolor.get(hex, hex))
	if look.has("textures"):
		var pkey := "pbr|%s|%s|%s" % [look.textures, p.kind, hex]
		if not _mats.has(pkey): _mats[pkey] = _lab_material(p.kind, Color(hex))
		return _mats[pkey]
	var key := "%s|%s" % [p.kind, hex]
	if not _mats.has(key):
		var m := (Palette.detailed(Color(hex), KINDS.get(p.kind, "mottle")) as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = false   # glTF vertex colours are linear
		if p.kind in ["glass", "metal"]:
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			m.roughness = 0.25 if p.kind == "glass" else 0.45
			m.metallic_specular = 0.6
		_mats[key] = m
	return _mats[key]

## Loads a model and restyles every wh_ material on it.
static func load_model(path: String, recolor: Dictionary = {}) -> Node3D:
	var scene: PackedScene = load(path)
	if scene == null: return null
	var root: Node3D = scene.instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			var m := material_for(src.resource_name, recolor) if src else null
			if m: mi.set_surface_override_material(i, m)
	return root

## Look-dev: places the models a lab file lists in the world, and hides buildings it names. The file:
## {"hide": [building ids], "models": [{"glb": "res://...", "x": 0, "z": 0, "yaw": 0, "recolor": {...},
##   "anim": "walk", "seek": 0.25}]}: a rigged model is held in that pose of that animation (seconds in).
static func place_lab(village: Village, path: String) -> Array:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if spec.has("look"):
		look = spec.look.duplicate()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--labtex="): look["textures"] = a.trim_prefix("--labtex=")
			if a.begins_with("--labwet="): look["wet"] = float(a.trim_prefix("--labwet="))
			if a == "--labnpcs": look["hide_npcs"] = false
			if a == "--labchars=0": look["characters"] = false
		_finish_look(village)
	for id in spec.get("hide", []):
		var o: Node3D = village.objects.get(id)
		if o: o.visible = false
	var placed: Array = []
	for m: Dictionary in spec.get("models", []):
		var node := _prop(m) if m.has("prop") else load_model(m.glb, m.get("recolor", {}))
		if node == null: push_error("model lab: cannot load %s" % m.get("glb", m.get("prop"))); continue
		var x := float(m.x); var z := float(m.z)
		node.position = Vector3(x, maxf(0.0, Heightfield.height(x, z)) + float(m.get("y", 0.0)), z)
		node.rotation.y = float(m.get("yaw", 0.0))
		node.rotation.z = float(m.get("roll", 0.0))
		village.add_child(node); placed.append(node)
		if m.has("anim"):
			var ap: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false).front()
			if ap and ap.has_animation(m.anim):
				ap.play(m.anim); ap.seek(float(m.get("seek", 0.0)), true); ap.pause()
			else: push_error("model lab: %s has no animation %s" % [m.glb, m.anim])
	return placed

static func _prop(m: Dictionary) -> Node3D:
	match String(m.prop):
		"bike": return BikeModel.build(String(m.get("color", "c0392b")), m.get("ups", []))
	return null

static func _texture(path: String) -> Texture2D:
	if not _tex.has(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			_tex[path] = null
		else:
			img.generate_mipmaps()
			_tex[path] = ImageTexture.create_from_image(img)
	return _tex[path]

static func pbr_material(kind: String, color: Color, textures: String, world: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	var plain: Array = PBR_PLAIN.get(kind, [0.8, 0.0])
	m.roughness = plain[0]
	m.metallic = plain[1]
	var spec: Array = PBR_TEX.get(kind, [])
	if spec.is_empty() or textures == "": return m
	var base := "res://assets/textures/lab/%s/%s" % [texture_set(spec[0], textures), spec[0]]
	var alb := _texture(base + "_albedo.jpg")
	if alb == null: return m
	m.albedo_texture = alb
	m.albedo_color = Color(color.r * NEUTRAL_GAIN, color.g * NEUTRAL_GAIN, color.b * NEUTRAL_GAIN) if spec[3] else Color.WHITE
	m.normal_enabled = true
	m.normal_texture = _texture(base + "_normal.jpg")
	m.normal_scale = float(spec[2])
	m.roughness_texture = _texture(base + "_rough.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_triplanar_sharpness = 6.0
	m.uv1_scale = Vector3.ONE / float(spec[1])
	return m

static func _lab_material(kind: String, color: Color) -> Material:
	var wet := float(look.get("wet", 0.0))
	if kind != "paving" or wet <= 0.0: return pbr_material(kind, color, String(look.textures))
	var base := "res://assets/textures/lab/%s/paving" % texture_set("paving", String(look.textures))
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WET_PAVING
	sm.shader = sh
	sm.set_shader_parameter("albedo_tex", _texture(base + "_albedo.jpg"))
	sm.set_shader_parameter("normal_tex", _texture(base + "_normal.jpg"))
	sm.set_shader_parameter("rough_tex", _texture(base + "_rough.jpg"))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.noise = noise
	sm.set_shader_parameter("puddle_tex", nt)
	sm.set_shader_parameter("tile", float(PBR_TEX.paving[1]))
	sm.set_shader_parameter("wet", wet)
	return sm

static func _finish_look(village: Village) -> void:
	for i in 3: await village.get_tree().process_frame
	if look.get("ssr", false):
		for we: WorldEnvironment in village.get_tree().root.find_children("*", "WorldEnvironment", true, false):
			we.environment.ssr_enabled = true
			we.environment.ssr_max_steps = 96
			we.environment.ssr_fade_in = 0.12
			we.environment.ssr_fade_out = 2.0
			we.environment.ssr_depth_tolerance = 0.25
	var player: Node = village.get_parent().get("player_char")
	if look.get("hide_npcs", false):
		for n in village.get_tree().root.find_children("*", "Node3D", true, false):
			if n is Chibi and n != player:
				for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false): mi.visible = false
				for l: Label3D in n.find_children("*", "Label3D", true, false): l.text = ""
	if not look.get("characters", false) or not look.has("textures"): return
	var by_mat := {}
	for key in Palette._cache: by_mat[Palette._cache[key]] = String(key)
	for n in village.get_tree().root.find_children("*", "Node3D", true, false):
		if not (n is Chibi): continue
		var chi: Chibi = n
		var skin := Color(String(chi.appearance.get("skin", "ffffff")))
		var hair := Color(String(chi.appearance.get("hairColor", "000000")))
		for mi: MeshInstance3D in chi.find_children("*", "MeshInstance3D", true, false):
			var src := mi.material_override as StandardMaterial3D
			if src == null or not by_mat.has(src): continue
			var parts: PackedStringArray = String(by_mat[src]).split("|")
			var kind := parts[1] if parts.size() == 2 else "mottle"
			var col := src.albedo_color
			var y := mi.global_position.y - chi.global_position.y
			var lab_kind := ""
			if kind == "fabric":
				lab_kind = "leather" if y < 0.16 else ("denim" if y < 0.42 else "knit")
			elif kind == "smooth" and col.is_equal_approx(skin):
				lab_kind = "skin"
			elif col.is_equal_approx(hair):
				lab_kind = "wool"
			if lab_kind != "": mi.material_override = pbr_material(lab_kind, col, String(look.textures), false)

