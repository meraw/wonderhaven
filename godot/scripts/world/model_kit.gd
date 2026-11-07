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
	for id in spec.get("hide", []):
		var o: Node3D = village.objects.get(id)
		if o: o.visible = false
	var placed: Array = []
	for m: Dictionary in spec.get("models", []):
		var node := load_model(m.glb, m.get("recolor", {}))
		if node == null: push_error("model lab: cannot load %s" % m.glb); continue
		var x := float(m.x); var z := float(m.z)
		node.position = Vector3(x, maxf(0.0, Heightfield.height(x, z)), z)
		node.rotation.y = float(m.get("yaw", 0.0))
		village.add_child(node); placed.append(node)
		if m.has("anim"):
			var ap: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false).front()
			if ap and ap.has_animation(m.anim):
				ap.play(m.anim); ap.seek(float(m.get("seek", 0.0)), true); ap.pause()
			else: push_error("model lab: %s has no animation %s" % [m.glb, m.anim])
	return placed
