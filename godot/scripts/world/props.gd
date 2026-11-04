class_name Props
## Low-poly prop builders for Hearthglow Village. Each returns a Node3D centred on its footprint at ground level.
const P := preload("res://scripts/world/palette.gd")

static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadow: bool = true) -> MeshInstance3D:
	var m := P.mi(mesh, material, pos, shadow)
	m.rotation = rot; m.scale = scl
	parent.add_child(m)
	return m

## Leaf material for single trees: tinted by the canopy mesh's light-to-dark gradient. Stays a StandardMaterial3D
## so the interaction highlight can tint it.
static func leaf_mat(color: Color) -> StandardMaterial3D:
	var m := P.unique_mat(color)   # untextured: the canopy gradient is the detail
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	# dissolve leaves right in front of the camera, like the instanced trees (Foliage.PLANT_SHADER)
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = 1.9; m.distance_fade_max_distance = 2.8
	m.backlight_enabled = true; m.backlight = Color(color).darkened(0.35)   # sunlight glows through the leaves
	return m

static func round_tree(s: float = 1.0, hue: float = 0.5, fruit: bool = false) -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(0.13, 0.24, 1.5, 9), P.wood(P.TRUNK), Vector3(0, 0.75, 0))
	_add(g, P.cyl(0.05, 0.08, 0.6, 6), P.wood(P.TRUNK), Vector3(0.22, 1.35, 0.05), Vector3(0, 0, -0.7))
	var leaf := Color("6cc45e")
	leaf.h += (hue - 0.5) * 0.06; leaf.v += (hue - 0.5) * 0.08
	_add(g, Foliage.canopy(int(hue * 10.0) % 2), leaf_mat(leaf), Vector3(0, 2.0, 0), Vector3(0, hue * 6.0, 0))
	if fruit: add_fruit(g)
	g.scale = Vector3.ONE * s
	return g

## A pink ribbon tied round the trunk with a bow: the forester's mark on trees that are ready for cutting.
static func add_ribbon(tree: Node3D) -> Node3D:
	var r := Node3D.new(); r.name = "ribbon"
	var pink := P.fabric("ff6f9e")
	_add(r, P.torus(0.22, 0.045, 24), pink, Vector3(0, 0.95, 0), Vector3(0, 0, 0.08), Vector3(1, 1.8, 1))
	for s in [-1, 1]:
		_add(r, P.sphere(0.09, 12, 8), pink, Vector3(s * 0.08, 0.96, 0.24), Vector3(0, 0, s * 0.5), Vector3(1.0, 0.55, 0.45))
		_add(r, P.box(0.05, 0.22, 0.015), pink, Vector3(s * 0.05, 0.84, 0.235), Vector3(0, 0, s * 0.25))
	_add(r, P.sphere(0.035, 10, 8), P.fabric("e04f82"), Vector3(0, 0.96, 0.245))
	tree.add_child(r)
	return r

static func add_fruit(tree: Node3D) -> Node3D:
	var f := Node3D.new(); f.name = "fruit"
	# hazelnut clusters: a few small brown nuts in a pale green husk
	for p in [[0.95, 1.85, 0.55], [-0.75, 2.0, 0.75], [0.25, 1.55, -1.0], [-0.4, 2.6, -0.7], [1.05, 2.3, -0.4]]:
		_add(f, P.sphere(0.11, 8, 6), P.mat("a9c46a"), Vector3(p[0], p[1] + 0.05, p[2]), Vector3.ZERO, Vector3(1.2, 0.7, 1.2))
		for k in 3: _add(f, P.sphere(0.065, 8, 6), P.mat("a0703c"), Vector3(p[0] + cos(k * 2.1) * 0.07, p[1] - 0.03, p[2] + sin(k * 2.1) * 0.07))
	tree.add_child(f)
	return f

static func bush(s: float = 1.0, color: String = "69bf5f") -> Node3D:
	var g := Node3D.new()
	_add(g, Foliage.bush(), leaf_mat(Color(color)), Vector3.ZERO)
	g.scale = Vector3.ONE * s
	return g

static func rock(rich: bool = false) -> Node3D:
	var g := Node3D.new()
	_add(g, P.sphere(0.8, 6, 4), P.stone(P.STONE), Vector3(0, 0.4, 0), Vector3(0.2, 0.5, 0.1), Vector3(1.1, 0.75, 0.95))
	_add(g, P.sphere(0.45, 6, 4), P.stone(P.STONE_DARK), Vector3(0.55, 0.25, 0.35), Vector3(0.4, 0, 0.2))
	var vein = P.mat("b5653a") if rich else P.wood("d9a066")   # rich rocks show rusty iron
	for p in [[0.3, 0.75, 0.45], [-0.45, 0.55, 0.5], [0.1, 0.5, -0.7]]:
		_add(g, P.sphere(0.2 if rich else 0.12, 4, 2), vein, Vector3(p[0], p[1], p[2]), Vector3(0.6, 0.6, 0))
	return g

static func clay_mound() -> Node3D:
	var g := Node3D.new()
	_add(g, P.hemi(0.6, 10), P.mat("d98b5f"), Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 0.5, 1))
	for p in [[0.5, 0.3], [-0.4, 0.4], [0.1, -0.5]]: _add(g, P.sphere(0.18, 7, 5), P.mat("c97a50"), Vector3(p[0], 0.1, p[1]))
	return g

static func flower_patch() -> Node3D:
	var g := Node3D.new()
	for n in 9:
		var a := n * 2.4; var r := 0.2 + (n % 3) * 0.22
		_add(g, P.cyl(0.02, 0.02, 0.35, 4), P.mat("4f9e45"), Vector3(cos(a) * r, 0.17, sin(a) * r), Vector3.ZERO, Vector3.ONE, false)
		_add(g, P.sphere(0.11, 7, 5), P.mat(P.FLOWERS[n % 5]), Vector3(cos(a) * r, 0.38, sin(a) * r))
	return g

static func chest() -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(0.9, 0.45, 0.62, 0.05), P.wood("b5733f"), Vector3(0, 0.23, 0))
	var lid := Node3D.new(); lid.name = "lid"; lid.position = Vector3(0, 0.45, -0.31); g.add_child(lid)
	_add(lid, P.rbox(0.9, 0.22, 0.62, 0.08), P.wood("c98447"), Vector3(0, 0.1, 0.31))
	for x in [-0.3, 0.3]: _add(g, P.box(0.08, 0.47, 0.64), P.mat(P.GOLD), Vector3(x, 0.24, 0))
	_add(g, P.box(0.14, 0.16, 0.06), P.mat(P.GOLD), Vector3(0, 0.42, 0.33))
	return g

## Something somebody lost: a bunch of keys on a ring, lying in the grass and catching the light.
static func fragment() -> Node3D:
	var g := Node3D.new()
	var brass := P.unique_mat("e0b94a"); brass.metallic = 0.6; brass.roughness = 0.35; brass.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_add(g, P.torus(0.09, 0.018, 16), brass, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	for k in 2:
		var key := Node3D.new(); key.rotation.y = 0.5 + k * 0.9; g.add_child(key)
		_add(key, P.cyl(0.045, 0.045, 0.02, 10), brass, Vector3(0.14, 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
		_add(key, P.box(0.16, 0.018, 0.035), P.unique_mat("c9ced6") if k == 0 else brass, Vector3(0.26, 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	g.scale = Vector3.ONE * 1.6
	return g

## A big green street garbage bin on wheels, the kind every Italian village has. Copper wire hides inside.
static func garbage_bin() -> Node3D:
	var g := Node3D.new()
	var green := P.mat("3f7a4a"); var dark := P.mat("2c5434")
	_add(g, P.rbox(1.3, 1.15, 0.95, 0.08), green, Vector3(0, 0.72, 0))
	_add(g, P.box(1.32, 0.12, 0.97), dark, Vector3(0, 0.55, 0))
	_add(g, P.box(0.5, 0.18, 0.02), P.mat("f2f2ea"), Vector3(0, 0.95, 0.485))
	for x in [-0.5, 0.5]:
		for z in [-0.35, 0.35]: _add(g, P.cyl(0.11, 0.11, 0.08, 12), P.mat("26282a"), Vector3(x, 0.11, z), Vector3(0, 0, PI / 2))
	var lid := Node3D.new(); lid.name = "lid"; lid.position = Vector3(0, 1.3, -0.47); g.add_child(lid)
	_add(lid, P.rbox(1.36, 0.12, 1.0, 0.05), dark, Vector3(0, 0.0, 0.47))
	_add(g, P.box(0.3, 0.05, 0.12), dark, Vector3(0.35, 0.2, 0.52))
	return g

static func sign_post() -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(0.06, 0.07, 1.1, 6), P.wood(P.WOOD_DARK), Vector3(0, 0.55, 0))
	_add(g, P.rbox(1.0, 0.55, 0.1, 0.04), P.wood(P.WOOD), Vector3(0, 1.05, 0))
	return g

static func notice_board() -> Node3D:
	var g := Node3D.new()
	for x in [-0.6, 0.6]: _add(g, P.cyl(0.07, 0.08, 1.7, 6), P.wood(P.WOOD_DARK), Vector3(x, 0.85, 0))
	_add(g, P.rbox(1.4, 0.9, 0.1, 0.04), P.wood("d9a066"), Vector3(0, 1.2, 0))
	for n in [[-0.35, 1.3, "fff7e0"], [0.25, 1.15, "ffe0ec"], [-0.1, 0.98, "e0f4ff"]]: _add(g, P.box(0.4, 0.3, 0.01), P.mat(n[2]), Vector3(n[0], n[1], 0.06), Vector3.ZERO, Vector3.ONE, false)
	_add(g, P.box(1.6, 0.08, 0.3), P.mat("c25b4a"), Vector3(0, 1.72, 0))
	return g

static func wardrobe() -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(0.9, 1.7, 0.5, 0.06), P.mat("e9b3c9"), Vector3(0, 0.85, 0))
	_add(g, P.box(0.55, 1.1, 0.01), P.glow_mat(Color("cfefff")), Vector3(0, 0.95, 0.26))
	_add(g, P.cone(0.55, 0.3, 4), P.mat("d48aab"), Vector3(0, 1.85, 0), Vector3(0, PI / 4, 0))
	return g

const ROOF_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 color : source_color = vec4(0.8, 0.4, 0.3, 1.0);
uniform float alpha = 1.0;
uniform float row_h = 0.17;
uniform float tile_w = 0.42;
varying vec3 lp;
varying vec3 ln;
float h1(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	vec3 c = color.rgb;
	if (ln.y > 0.2) {
		// Fish-scale tiles: each course's rounded lower edge overlaps the course below it.
		float row = lp.y / row_h;
		float ri = floor(row); float rf = fract(row);
		float ux = lp.x / tile_w + mod(ri + 1.0, 2.0) * 0.5;
		float ucf = fract(ux);
		float dip = 0.42 * sqrt(max(0.0, 1.0 - pow(2.0 * ucf - 1.0, 2.0)));
		float edge = 1.0 - dip;
		vec2 id; float shade = 1.0;
		if (rf > edge) {
			id = vec2(ri + 1.0, floor(ux));
			shade = 1.06 - 0.1 * smoothstep(edge, edge + 0.06, rf) * 0.0;
		} else {
			id = vec2(ri, floor(lp.x / tile_w + mod(ri, 2.0) * 0.5));
			shade = 1.0 - 0.3 * smoothstep(edge - 0.3, edge, rf);
		}
		shade *= 1.0 - 0.45 * (1.0 - smoothstep(0.0, 0.05, abs(rf - edge)));
		shade *= 0.9 + 0.16 * h1(id);
		c *= shade;
	} else if (ln.y < -0.2) {
		c *= 0.62;
	} else {
		c *= 0.8;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	#FADE
}
"""

static var _roof_shaders: Dictionary = {}

## Tiled roof material. fade = true allows see-through (the workshop roof fades when you are inside).
static func roof_material(color, fade: bool = false) -> ShaderMaterial:
	var key := "fade" if fade else "solid"
	if not _roof_shaders.has(key):
		# The fading copy dissolves with a fine dither instead of real transparency, so it never hides what's
		# beneath it (transparent surfaces that write depth block the view of the room below).
		var dither := "if (fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) >= alpha) discard;"
		var sh := Shader.new(); sh.code = ROOF_SHADER.replace("#FADE", dither if fade else "")
		_roof_shaders[key] = sh
	var m := ShaderMaterial.new(); m.shader = _roof_shaders[key]
	m.set_shader_parameter("color", Color(color) if color is String else color)
	return m

## Gable roof slab with the ridge along X, centred on the origin at the eave-top height.
## w, d: wall footprint; rise: ridge height above the wall top; oh: overhang.
static func gable_roof_mesh(w: float, d: float, rise: float, oh: float, th: float = 0.14) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := rise / (d / 2.0)
	var x0 := -w / 2.0 - oh; var x1 := w / 2.0 + oh
	var ze := d / 2.0 + oh
	var quad := func(a: Vector3, b: Vector3, c: Vector3, e: Vector3) -> void:
		for p in [a, b, c, a, c, e]: st.add_vertex(p)
	for s in [-1.0, 1.0]:
		var rt := Vector3(0, rise + th, 0); var et := Vector3(0, rise + th - k * ze, s * ze)
		var rb := Vector3(0, rise, 0); var eb := Vector3(0, rise - k * ze, s * ze)
		var X0 := Vector3(x0, 0, 0); var X1 := Vector3(x1, 0, 0)
		if s > 0:
			quad.call(rt + X0, rt + X1, et + X1, et + X0)          # top
			quad.call(rb + X0, eb + X0, eb + X1, rb + X1)          # underside
			quad.call(et + X0, et + X1, eb + X1, eb + X0)          # eave edge
			quad.call(rt + X1, rb + X1, eb + X1, et + X1)          # gable edges
			quad.call(rt + X0, et + X0, eb + X0, rb + X0)
		else:
			quad.call(rt + X1, rt + X0, et + X0, et + X1)
			quad.call(rb + X1, eb + X1, eb + X0, rb + X0)
			quad.call(et + X1, et + X0, eb + X0, eb + X1)
			quad.call(rt + X0, rb + X0, eb + X0, et + X0)
			quad.call(rt + X1, et + X1, eb + X1, rb + X1)
	st.generate_normals()
	return st.commit()

## Roof, gable infill and ridge cap for a w x d building whose walls end at height h. Returns the roof node.
static func roof_rise(w: float, d: float) -> float: return clampf(minf(w, d) * 0.36, 1.2, 2.0)

## For each mesh under `nodes`: [mesh, solid material, dissolving copy]. game.gd swaps to the copies and dissolves
## them while you're inside, so the roof (and anything resting on it) gets out of the way.
static func fade_parts(nodes: Array) -> Array:
	var parts: Array = []
	for nd in nodes:
		var meshes: Array = nd.find_children("*", "MeshInstance3D", true, false)
		if nd is MeshInstance3D: meshes.append(nd)
		for m in meshes:
			var solid: Material = m.material_override
			var faded: Material
			if solid is ShaderMaterial:
				var c = (solid as ShaderMaterial).get_shader_parameter("color")
				faded = roof_material(c if c != null else Color.WHITE, true)
			elif solid is StandardMaterial3D:
				faded = (solid as StandardMaterial3D).duplicate()
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH; faded.alpha_hash_scale = 1.0
			else: continue
			parts.append([m, solid, faded])
	return parts

## Rooms you can walk into (the workshop): while the player is inside, the camera stays within the walls.
static func camera_rooms() -> Array:
	var out: Array = []
	for b in Data.layout.buildings:
		if b.kind == "workshop":
			out.append(AABB(Vector3(b.x - b.w / 2.0 + 0.35, -1.0, b.z - b.d / 2.0 + 0.35), Vector3(b.w - 0.7, 3.6, b.d - 0.7)))
		elif Interiors.enterable(b):
			out.append(Interiors.room(b, Heightfield.CASTLE_MOUND.y if b.kind == "castle" else 0.0))
	return out

## Boxes the follow camera should not pass through: every building's walls and roof (overhang included).
static func camera_blockers() -> Array:
	var out: Array = []
	for b in Data.layout.buildings:
		var pad := 1.1 if b.kind == "castle" else 0.4
		var top: float = 6.5 if b.kind == "castle" else (3.0 if b.kind == "caravan" else (9.0 if b.kind in ["lighthouse", "clocktower"] else 2.6 + roof_rise(b.w, b.d) + 0.3))
		out.append(AABB(Vector3(b.x - b.w / 2.0 - pad, -1.0, b.z - b.d / 2.0 - pad), Vector3(b.w + pad * 2.0, top + 1.0, b.d + pad * 2.0)))
	return out

static func _gable_roof(g: Node3D, w: float, d: float, h: float, wall_mat: Material, roof_mat: Material, ridge_color) -> Node3D:
	var along_x := w >= d
	var L := w if along_x else d
	var S := d if along_x else w
	var rise := roof_rise(w, d)
	var node := Node3D.new(); node.name = "roof"; node.position.y = h
	if not along_x: node.rotation.y = PI / 2
	g.add_child(node)
	_add(node, gable_roof_mesh(L, S, rise, 0.38), roof_mat, Vector3.ZERO)
	var infill := PrismMesh.new(); infill.size = Vector3(S, rise, L); infill.left_to_right = 0.5
	_add(node, infill, wall_mat, Vector3(0, rise / 2.0, 0), Vector3(0, PI / 2, 0))
	_add(node, P.rbox(L + 0.9, 0.2, 0.26, 0.08), P.mat(ridge_color), Vector3(0, rise + 0.17, 0))
	node.set_meta("rise", rise); node.set_meta("length", L); node.set_meta("span", S)
	return node

static func _window(shutter = null) -> Node3D:
	var w := Node3D.new()
	_add(w, P.rbox(0.86, 0.9, 0.12, 0.04), P.mat("fffaf0"), Vector3.ZERO)
	var glass := _add(w, P.box(0.64, 0.68, 0.02), P.unique_mat("a9ddf5", "ffcf6b", 0.0), Vector3(0, 0, 0.055), Vector3.ZERO, Vector3.ONE, false)
	glass.name = "glass"
	_add(w, P.box(0.05, 0.68, 0.03), P.mat("fffaf0"), Vector3(0, 0, 0.07))
	_add(w, P.box(0.64, 0.05, 0.03), P.mat("fffaf0"), Vector3(0, 0.04, 0.07))
	_add(w, P.rbox(1.0, 0.08, 0.2, 0.03), P.mat("fffaf0"), Vector3(0, -0.47, 0.06))
	if shutter != null:
		for sx in [-1, 1]:
			var sh := _add(w, P.rbox(0.3, 0.92, 0.06, 0.03), P.mat(shutter), Vector3(sx * 0.62, 0, 0.04))
			for y in [-0.22, 0.0, 0.22]: _add(sh, P.box(0.22, 0.03, 0.02), P.mat(Color(shutter).darkened(0.18)), Vector3(0, y, 0.035), Vector3.ZERO, Vector3.ONE, false)
	return w

static func _flower_box(parent: Node3D, seed: int) -> void:
	_add(parent, P.rbox(0.92, 0.2, 0.24, 0.04), P.wood(P.WOOD), Vector3(0, -0.62, 0.15))
	_add(parent, P.box(0.84, 0.04, 0.18), P.wood("6b4a32"), Vector3(0, -0.51, 0.15), Vector3.ZERO, Vector3.ONE, false)
	for i in 5:
		var x := -0.34 + i * 0.17
		_add(parent, P.sphere(0.09, 8, 6), P.mat("5fae4f"), Vector3(x, -0.47, 0.15 + (0.03 if i % 2 else -0.02)), Vector3.ZERO, Vector3(1, 0.8, 1), false)
		_add(parent, P.sphere(0.05, 6, 4), P.mat(P.FLOWERS[(seed + i) % P.FLOWERS.size()]), Vector3(x + 0.03, -0.39, 0.2), Vector3.ZERO, Vector3.ONE, false)

static func _on_side(obj: Node3D, b: Dictionary, side: String, y: float, offset: float = 0.0, out: float = 0.02) -> void:
	var hw: float = b.w / 2.0 + out
	var hd: float = b.d / 2.0 + out
	match side:
		"S": obj.position = Vector3(offset, y, hd)
		"N": obj.position = Vector3(offset, y, -hd); obj.rotation.y = PI
		"E": obj.position = Vector3(hw, y, offset); obj.rotation.y = PI / 2
		"W": obj.position = Vector3(-hw, y, offset); obj.rotation.y = -PI / 2

static func _door(g: Node3D, b: Dictionary, color: String = "a0623a", canopy = null) -> void:
	var door := Node3D.new()
	var open := Interiors.enterable(b)
	if open:
		# a frame round an open doorway, the door swung inwards against the wall
		var fm := P.mat("fffaf0")
		for x in [-0.66, 0.66]: _add(door, P.box(0.12, 2.05, 0.3), fm, Vector3(x, 0.22, -0.08))
		_add(door, P.box(1.44, 0.14, 0.3), fm, Vector3(0, 1.25, -0.08))
		var hinge := Node3D.new(); hinge.position = Vector3(-0.56, 0, -0.2); hinge.rotation.y = 1.75; door.add_child(hinge)
		_add(hinge, P.rbox(1.0, 1.62, 0.08, 0.04), P.wood(color), Vector3(0.5, 0, 0))
		_add(hinge, P.sphere(0.06, 8, 6), P.mat(P.GOLD), Vector3(0.85, 0, 0.06))
	else:
		_add(door, P.rbox(1.24, 1.86, 0.1, 0.04), P.mat("fffaf0"), Vector3(0, 0.1, -0.02))
		_add(door, P.rbox(1.0, 1.62, 0.12, 0.05), P.wood(color), Vector3.ZERO)
		for x in [-0.25, 0.25]: _add(door, P.box(0.04, 1.3, 0.02), P.mat(Color(color).darkened(0.2)), Vector3(x, 0, 0.065), Vector3.ZERO, Vector3.ONE, false)
		_add(door, P.sphere(0.06, 8, 6), P.mat(P.GOLD), Vector3(0.33, 0, 0.09))
	_add(door, P.rbox(1.5, 0.12, 0.6, 0.05), P.stone(P.STONE), Vector3(0, -0.76, 0.3))
	if canopy != null:
		var cn := Node3D.new(); cn.position = Vector3(0, 1.16, 0.32); door.add_child(cn)
		for s in [-1, 1]: _add(cn, P.rbox(0.82, 0.07, 0.72, 0.03), canopy, Vector3(s * 0.36, 0.17, 0), Vector3(0, 0, -s * 0.45))
		for x in [-0.66, 0.66]: _add(cn, P.box(0.06, 0.06, 0.6), P.wood(P.WOOD_DARK), Vector3(x, -0.05, 0.0), Vector3(0.6, 0, 0))
	_on_side(door, b, b.door, 0.8, float(b.get("doorOffset", 0)))
	g.add_child(door)

static func cottage(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := 2.4
	var wall_mat := P.plaster(b.wall)
	var trim := Color(b.roof).darkened(0.35).lerp(Color(P.WOOD_DARK), 0.6)
	var enter := Interiors.enterable(b)
	if enter:
		# walls with a doorway (the same rectangles the collision uses), a lintel, a plank floor and a plinth ring
		for r in Interiors.walls(b):
			_add(g, P.box(r.maxX - r.minX, h, r.maxZ - r.minZ), wall_mat, Vector3((r.minX + r.maxX) / 2.0 - b.x, h / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z))
		var di := Interiors.door_info(b)
		var dc: Vector2 = di.c - Vector2(b.x, b.z) - di.out * (Interiors.WALL_T / 2.0)
		var lw := Vector3(Interiors.DOOR_W, h - Interiors.DOOR_H, Interiors.WALL_T) if di.out.y != 0.0 else Vector3(Interiors.WALL_T, h - Interiors.DOOR_H, Interiors.DOOR_W)
		_add(g, P.box(lw.x, lw.y, lw.z), wall_mat, Vector3(dc.x, (h + Interiors.DOOR_H) / 2.0, dc.y))
		_add(g, P.box(b.w - 0.1, 0.05, b.d - 0.1), P.wood("d9b48a"), Vector3(0, 0.025, 0), Vector3.ZERO, Vector3.ONE, false)
		for zs in [-1, 1]: _add(g, P.box(b.w + 0.24, 0.32, 0.14), P.stone("c9bfae"), Vector3(0, 0.1, zs * (b.d / 2.0 + 0.05)))
		for xs in [-1, 1]: _add(g, P.box(0.14, 0.32, b.d + 0.24), P.stone("c9bfae"), Vector3(xs * (b.w / 2.0 + 0.05), 0.1, 0))
	else:
		_add(g, P.rbox(b.w, h, b.d, 0.06), wall_mat, Vector3(0, h / 2.0, 0))
		_add(g, P.rbox(b.w + 0.24, 0.4, b.d + 0.24, 0.08), P.stone("c9bfae"), Vector3(0, 0.15, 0))
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		_add(g, P.box(0.2, h, 0.2), P.wood(trim), Vector3(c[0] * (b.w / 2.0 - 0.06), h / 2.0, c[1] * (b.d / 2.0 - 0.06)))
	if enter:
		for zs in [-1, 1]: _add(g, P.box(b.w + 0.06, 0.16, 0.3), P.wood(trim), Vector3(0, h - 0.08, zs * (b.d / 2.0 - 0.12)))
		for xs in [-1, 1]: _add(g, P.box(0.3, 0.16, b.d + 0.06), P.wood(trim), Vector3(xs * (b.w / 2.0 - 0.12), h - 0.08, 0))
	else:
		_add(g, P.box(b.w + 0.06, 0.16, b.d + 0.06), P.wood(trim), Vector3(0, h - 0.08, 0))
	var roof := _gable_roof(g, b.w, b.d, h, wall_mat, roof_material(b.roof), Color(b.roof).darkened(0.25))
	var rise: float = roof.get_meta("rise"); var L: float = roof.get_meta("length"); var S: float = roof.get_meta("span")
	# Stone chimney poking through one slope, near the ridge.
	var ch_local := Vector3(L * 0.28, 0, -S * 0.18)
	var ch := ch_local if b.w >= b.d else Vector3(-ch_local.z, 0, ch_local.x)
	var top := h + rise + 0.55
	_add(g, P.rbox(0.55, top - h, 0.55, 0.05), P.stone("b9ada0"), Vector3(ch.x, h + (top - h) / 2.0, ch.z))
	var chim := _add(g, P.rbox(0.7, 0.14, 0.7, 0.04), P.stone("8f8378"), Vector3(ch.x, top, ch.z))
	var chimney_mesh: MeshInstance3D = g.get_child(g.get_child_count() - 2)
	g.set_meta("chimney", Vector3(ch.x, top + 0.2, ch.z))
	var over_room: Array = [roof, chim, chimney_mesh]   # what fades away while you're inside
	# Round attic windows in both gable ends.
	for s in [-1, 1]:
		var aw := Node3D.new(); over_room.append(aw)
		var gx: float = (b.w / 2.0 + 0.02) * s if b.w >= b.d else 0.0
		var gz: float = 0.0 if b.w >= b.d else (b.d / 2.0 + 0.02) * s
		aw.position = Vector3(gx, h + rise * 0.42, gz); aw.rotation.y = (PI / 2 if s > 0 else -PI / 2) if b.w >= b.d else (0.0 if s > 0 else PI)
		_add(aw, P.torus(0.24, 0.05, 16), P.mat("fffaf0"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
		_add(aw, P.cyl(0.22, 0.22, 0.02, 16), P.unique_mat("a9ddf5"), Vector3.ZERO, Vector3(PI / 2, 0, 0), Vector3.ONE, false)
		g.add_child(aw)
	_door(g, b, "a0623a", null if b.get("inn", false) else roof_material(b.roof))   # the inn's name board sits over its door instead
	var shutter := Color(b.roof).lightened(0.05)
	var glasses: Array = []
	var seed := int(absf(b.x * 3.0 + b.z))
	var spots: Array = []   # [side, offset] of every window
	for s in ["N", "S", "E", "W"]:
		if s == b.door: continue
		var long: float = b.w if s in ["N", "S"] else b.d
		for off in ([-long * 0.25, long * 0.25] if long > 4.5 else [0.0]): spots.append([s, off])
	if b.door in ["N", "S"]:
		for off in [-b.w * 0.3, b.w * 0.3]: spots.append([b.door, off])
	for sp in spots:
		var w := _window(shutter); _on_side(w, b, sp[0], 1.4, sp[1]); g.add_child(w); glasses.append(w.get_node("glass"))
		_flower_box(w, seed); seed += 2
		if enter:
			# the same window seen from inside
			var wi := _window(); _on_side(wi, b, sp[0], 1.4, sp[1], -Interiors.WALL_T - 0.03); wi.rotation.y += PI; g.add_child(wi); glasses.append(wi.get_node("glass"))
	g.set_meta("glasses", glasses)
	if enter: g.set_meta("fade_parts", fade_parts(over_room))
	if b.get("inn", false): _inn_sign(g, b)
	if b.has("awning"):
		var aw := Node3D.new(); _on_side(aw, b, b.door, 2.12, 0, 0.4)
		var n := 8; var span: float = b.w * 0.86
		for i in n:
			_add(aw, P.box(span / n, 0.06, 0.9), P.mat(b.awning if i % 2 == 0 else "fff7f0"), Vector3(-span / 2.0 + (i + 0.5) * span / n, 0, 0), Vector3(-0.38, 0, 0))
			_add(aw, P.sphere(span / n / 2.0, 8, 4), P.mat(b.awning if i % 2 == 0 else "fff7f0"), Vector3(-span / 2.0 + (i + 0.5) * span / n, -0.17, 0.42), Vector3.ZERO, Vector3(1, 0.5, 0.3), false)
		g.add_child(aw)
	return g

## Hanging sign with a lantern picture and two lanterns by the door, so the inn reads as the inn.
static func _inn_sign(g: Node3D, b: Dictionary) -> void:
	var holder := Node3D.new(); _on_side(holder, b, b.door, 0.0, float(b.get("doorOffset", 0)) + 1.55, 0.05); g.add_child(holder)
	var iron := P.mat("3e4f48")
	_add(holder, P.box(0.06, 0.06, 0.75), iron, Vector3(0, 2.25, 0.36))
	for x in [-0.28, 0.28]: _add(holder, P.cyl(0.008, 0.008, 0.16, 4), iron, Vector3(x, 2.15, 0.64))
	var board := _add(holder, P.rbox(0.82, 0.5, 0.06, 0.05), P.wood("2f5f9e"), Vector3(0, 1.84, 0.64), Vector3(0, PI / 2, 0))
	board.name = "inn_board"
	_add(holder, P.rbox(0.66, 0.36, 0.07, 0.04), P.mat("fff3d6"), Vector3(0, 1.84, 0.64), Vector3(0, PI / 2, 0))
	_add(holder, P.cyl(0.07, 0.06, 0.16, 8), P.unique_mat("ffd36b", "ffb347", 0.6), Vector3(0, 1.84, 0.64))
	_add(holder, P.cone(0.09, 0.07, 8), iron, Vector3(0, 1.96, 0.64))
	# name board above the door, facing the street
	var front := Node3D.new(); _on_side(front, b, b.door, 2.1, float(b.get("doorOffset", 0)), 0.06); g.add_child(front)
	_add(front, P.rbox(1.9, 0.42, 0.08, 0.06), P.wood("2f5f9e"), Vector3(0, 0, 0.04))
	_add(front, P.rbox(1.76, 0.3, 0.09, 0.05), P.mat("fff3d6"), Vector3(0, 0, 0.05))
	var txt := Label3D.new(); txt.text = "Guest House"; txt.font = UiTheme.title_font(); txt.font_size = 64; txt.pixel_size = 0.0036
	txt.modulate = Color("2f5f9e"); txt.outline_size = 0; txt.position = Vector3(0, -0.005, 0.1); txt.shaded = true; txt.double_sided = false
	front.add_child(txt)
	for x in [-0.95, 0.95]:
		var lan := Node3D.new(); _on_side(lan, b, b.door, 1.75, float(b.get("doorOffset", 0)) + x, 0.12); g.add_child(lan)
		_add(lan, P.box(0.05, 0.05, 0.2), iron, Vector3(0, 0.12, 0.08))
		var bulb := _add(lan, P.cyl(0.08, 0.07, 0.18, 6), P.unique_mat("fff1b8", "ffcf6b", 0.8), Vector3(0, 0, 0.18)); bulb.name = "inn_lantern"
		_add(lan, P.cone(0.11, 0.08, 6), iron, Vector3(0, 0.13, 0.18))

static func workshop(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := 2.6; var t := 0.35
	var hw: float = b.w / 2.0; var hd: float = b.d / 2.0
	var wall_mat := P.texturize(P.unique_mat(b.wall), "plaster")
	var g0: float = b.doorAt - b.z - b.doorWidth / 2.0
	var g1: float = b.doorAt - b.z + b.doorWidth / 2.0
	var walls := Node3D.new(); walls.name = "walls"; g.add_child(walls)
	var addw := func(w: float, d: float, x: float, z: float): _add(walls, P.box(w, h, d), wall_mat, Vector3(x, h / 2.0, z))
	addw.call(b.w, t, 0.0, -hd + t / 2.0); addw.call(b.w, t, 0.0, hd - t / 2.0); addw.call(t, b.d, -hw + t / 2.0, 0.0)
	addw.call(t, g0 + hd, hw - t / 2.0, (-hd + g0) / 2.0); addw.call(t, hd - g1, hw - t / 2.0, (g1 + hd) / 2.0)
	_add(walls, P.box(t, h - 1.9, g1 - g0), wall_mat, Vector3(hw - t / 2.0, 1.9 + (h - 1.9) / 2.0, (g0 + g1) / 2.0))
	_add(g, P.box(b.w - 0.2, 0.06, b.d - 0.2), P.wood("d9b48a"), Vector3(0, 0.03, 0))
	var x := -hw + 0.6
	while x < hw:
		_add(g, P.box(0.03, 0.065, b.d - 0.3), P.wood("c49a6c"), Vector3(x, 0.035, 0), Vector3.ZERO, Vector3.ONE, false); x += 0.9
	# The roof is drawn solid; while you are inside, game.gd swaps each part to a see-through copy and fades it.
	# (Keeping it solid otherwise avoids sorting glitches and keeps the ink lines from showing through it.)
	var roof := _gable_roof(g, b.w, b.d, h, P.texturize(P.unique_mat(b.wall), "plaster"), roof_material(b.roof), Color(b.roof).darkened(0.25))
	_add(roof, P.box(b.w if b.w >= b.d else b.d, 0.1, b.d if b.w >= b.d else b.w), P.unique_mat(Color(b.roof).darkened(0.3)), Vector3(0, 0.05, 0))
	g.set_meta("fade_parts", fade_parts([roof]))
	# trim beams along the wall tops: a frame, not a slab, so the room stays open when the roof fades
	var trim := P.wood(Color(b.roof).darkened(0.35).lerp(Color(P.WOOD_DARK), 0.6))
	for zs in [-1, 1]: _add(g, P.box(b.w + 0.06, 0.16, t + 0.06), trim, Vector3(0, h - 0.08, zs * (hd - t / 2.0)))
	for xs in [-1, 1]: _add(g, P.box(t + 0.06, 0.16, b.d + 0.06), trim, Vector3(xs * (hw - t / 2.0), h - 0.08, 0))
	_add(g, P.rbox(1.6, 0.5, 0.1, 0.05), P.wood("8b5a3c"), Vector3(hw + 0.1, 2.25, b.doorAt - b.z - 1.6), Vector3(0, PI / 2, 0))
	var gear := _add(g, P.torus(0.22, 0.07, 10), P.mat(P.GOLD), Vector3(hw + 0.17, 2.25, b.doorAt - b.z - 1.6), Vector3(0, 0, PI / 2))
	gear.name = "signGear"
	for off in [-1.8, 1.8]: var w := _window(Color(b.roof).lightened(0.05)); _on_side(w, b, "S", 1.5, off); g.add_child(w); _flower_box(w, int(off))
	for off in [-2.0, 2.0]: var w := _window(Color(b.roof).lightened(0.05)); _on_side(w, b, "N", 1.5, off); g.add_child(w)
	var clutter := Node3D.new(); clutter.name = "clutter"; g.add_child(clutter)
	for c in [[-3.3, -2.4, 0.6], [-3.6, 2.4, 0.5], [2.6, 2.6, 0.55]]: _add(clutter, P.rbox(c[2], c[2], c[2], 0.04), P.mat("a88a6a"), Vector3(c[0], c[2] / 2.0, c[1]), Vector3(0, c[0], 0))
	for c in [[-hw + 0.4, -hd + 0.4, 0.8], [-hw + 0.4, hd - 0.4, -0.8]]: _add(clutter, P.box(0.8, 0.6, 0.01), P.glow_mat(Color("e8e8e8"), 0.5), Vector3(c[0], 2.3, c[1]), Vector3(0, c[2], 0), Vector3.ONE, false)
	return g

static func caravan(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(b.w, 1.7, b.d, 0.3), P.wood(b.wall), Vector3(0, 1.35, 0))
	_add(g, P.cyl(b.d / 2.0 + 0.15, b.d / 2.0 + 0.15, b.w + 0.2, 14), P.mat(b.roof), Vector3(0, 2.15, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.9))
	for p in [[-1.2, b.d / 2.0], [1.2, b.d / 2.0], [-1.2, -b.d / 2.0], [1.2, -b.d / 2.0]]: _add(g, P.torus(0.35, 0.08, 12), P.wood("8b5a3c"), Vector3(p[0], 0.38, p[1]), Vector3(PI / 2, 0, 0))
	_add(g, P.cyl(0.12, 0.12, 0.7), P.mat("555555"), Vector3(1.3, 2.9, 0))
	var cog := _add(g, P.torus(0.3, 0.09, 8), P.mat(P.GOLD), Vector3(0, 1.5, b.d / 2.0 + 0.05), Vector3(PI / 2, 0, 0)); cog.name = "cog"
	_door(g, b, "7a4a8a")
	return g

## Height of the castle's floor above its mound: furniture stands on it.
const CASTLE_FLOOR := 0.02

static func castle(b: Dictionary) -> Node3D:
	if not Interiors.enterable(b): return _castle_closed(b)
	# Curtain wall and keep, both with a gateway on the door side; a throne room inside the keep.
	var g := Node3D.new()
	var light := P.stone("eadfcd"); var keep_mat := P.stone(b.wall)
	for r in Interiors.walls(b):
		var hh: float = r.h
		_add(g, P.box(r.maxX - r.minX, hh, r.maxZ - r.minZ), light if hh < 3.0 else keep_mat, Vector3((r.minX + r.maxX) / 2.0 - b.x, hh / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z))
		if hh < 3.0:
			# crenellations along the curtain wall
			var horiz: bool = r.maxX - r.minX > r.maxZ - r.minZ
			var length: float = (r.maxX - r.minX) if horiz else (r.maxZ - r.minZ)
			var n := int(length / 0.9)
			for i in n:
				var t := (i + 0.5) / n
				var cx: float = lerpf(r.minX, r.maxX, t) if horiz else (r.minX + r.maxX) / 2.0
				var cz: float = (r.minZ + r.maxZ) / 2.0 if horiz else lerpf(r.minZ, r.maxZ, t)
				_add(g, P.box(0.45, 0.45, 0.45), light, Vector3(cx - b.x, hh + 0.22, cz - b.z))
	# lintels over both gateways
	var di := Interiors.door_info(b)
	for pair in [[b.w / 2.0, 0.5, 2.4], [b.w / 2.0 - 1.0, 0.35, 4.2]]:
		var c: Vector2 = Vector2(b.x, b.z) + di.out * (pair[0] - pair[1] / 2.0) - Vector2(b.x, b.z)
		var size := Vector3(Interiors.DOOR_W, pair[2] - Interiors.DOOR_H, pair[1]) if di.out.y != 0.0 else Vector3(pair[1], pair[2] - Interiors.DOOR_H, Interiors.DOOR_W)
		_add(g, P.box(size.x, size.y, size.z), light if pair[2] < 3.0 else keep_mat, Vector3(c.x, (pair[2] + Interiors.DOOR_H) / 2.0, c.y))
	# a stone base under the whole castle (it hides where the mound slopes away at the corners) and the hall's floor
	_add(g, P.box(b.w + 0.1, 1.2, b.d + 0.1), P.stone("cfc6b6"), Vector3(0, CASTLE_FLOOR - 0.01 - 0.6, 0), Vector3.ZERO, Vector3.ONE, false)
	_add(g, P.box(b.w - 2.4, 0.02, b.d - 2.4), P.stone("d8d0c2"), Vector3(0, CASTLE_FLOOR - 0.01, 0), Vector3.ZERO, Vector3.ONE, false)
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var tx: float = c[0] * b.w / 2.0; var tz: float = c[1] * b.d / 2.0
		_add(g, P.cyl(1.0, 1.1, 5.2, 14), P.stone(b.wall), Vector3(tx, 2.6, tz))
		_add(g, P.cone(1.3, 2.2, 14), P.mat(b.roof), Vector3(tx, 6.3, tz))
		_add(g, P.cyl(0.03, 0.03, 0.9, 4), P.mat("666666"), Vector3(tx, 7.8, tz))
		_add(g, P.box(0.6, 0.35, 0.02), P.mat("ff6f91"), Vector3(tx + 0.3, 8.05, tz))
	var kr := P.mi(P.cone((b.w - 2) * 0.62, 2.6, 4), P.mat(b.roof), Vector3.ZERO); kr.rotation.y = PI / 4
	var kh := Node3D.new(); kh.position.y = 5.5; kh.scale = Vector3(1, 1, (b.d - 2) / (b.w - 2)); kh.add_child(kr); g.add_child(kh)
	var ceiling := _add(g, P.box(b.w - 2.0, 0.1, b.d - 2.0), P.stone("d8d0c2"), Vector3(0, 4.25, 0))
	g.set_meta("fade_parts", fade_parts([kh, ceiling]))
	# banner over the gate
	var gate_c: Vector2 = di.out * (b.w / 2.0 + 0.08)
	var bn := _add(g, P.box(0.02, 1.6, 0.9) if di.out.y == 0.0 else P.box(0.9, 1.6, 0.02), P.fabric("ff6f91"), Vector3(gate_c.x, 3.4, gate_c.y))
	_add(g, P.sphere(0.25, 4, 2), P.mat(P.GOLD), Vector3(gate_c.x * 1.01, 3.5, gate_c.y * 1.01))
	return g

static func _castle_closed(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(b.w - 2, 4.2, b.d - 2, 0.15), P.plaster(b.wall), Vector3(0, 2.1, 0))
	var wall_h := 2.4
	_add(g, P.rbox(b.w, wall_h, b.d, 0.12), P.stone("eadfcd"), Vector3(0, wall_h / 2.0, 0))
	var x: float = -b.w / 2.0 + 0.4
	while x <= b.w / 2.0 - 0.4:
		for z in [-b.d / 2.0, b.d / 2.0]: _add(g, P.box(0.45, 0.45, 0.4), P.stone("eadfcd"), Vector3(x, wall_h + 0.22, z))
		x += 0.9
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var tx: float = c[0] * b.w / 2.0; var tz: float = c[1] * b.d / 2.0
		_add(g, P.cyl(1.0, 1.1, 5.2, 14), P.stone(b.wall), Vector3(tx, 2.6, tz))
		_add(g, P.cone(1.3, 2.2, 14), P.mat(b.roof), Vector3(tx, 6.3, tz))
		_add(g, P.cyl(0.03, 0.03, 0.9, 4), P.mat("666666"), Vector3(tx, 7.8, tz))
		_add(g, P.box(0.6, 0.35, 0.02), P.mat("ff6f91"), Vector3(tx + 0.3, 8.05, tz))
	var kr := P.mi(P.cone((b.w - 2) * 0.62, 2.6, 4), P.mat(b.roof), Vector3.ZERO); kr.rotation.y = PI / 4
	var kh := Node3D.new(); kh.position.y = 5.5; kh.scale = Vector3(1, 1, (b.d - 2) / (b.w - 2)); kh.add_child(kr); g.add_child(kh)
	_add(g, P.rbox(0.15, 2.0, 1.6, 0.06), P.wood("7a4a2a"), Vector3(-b.w / 2.0 - 0.05, 1.0, 0))
	_add(g, P.torus(0.8, 0.12, 12), P.stone(P.STONE_DARK), Vector3(-b.w / 2.0 - 0.08, 1.8, 0), Vector3(0, PI / 2, 0), Vector3(1, 1, 1))
	_add(g, P.box(0.02, 1.6, 0.9), P.mat("ff6f91"), Vector3(-b.w / 2.0 - 0.08, 3.4, 0))
	_add(g, P.sphere(0.25, 4, 2), P.mat(P.GOLD), Vector3(-b.w / 2.0 - 0.12, 3.5, 0))
	for z in [-2.2, 2.2]: var w := _window(); w.position = Vector3(-b.w / 2.0 - 0.02, 1.5, z); w.rotation.y = -PI / 2; g.add_child(w)
	return g

static func fountain() -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(2.05, 2.1, 0.12, 32), P.stone("cfc6b8"), Vector3(0, 0.06, 0))
	_add(g, P.cyl(1.7, 1.8, 0.55, 32), P.stone(P.STONE), Vector3(0, 0.3, 0))
	_add(g, P.cyl(1.45, 1.45, 0.58, 32), P.stone("b8b0a4"), Vector3(0, 0.32, 0))
	for i in 12:
		var a := TAU * i / 12.0
		_add(g, P.rbox(0.82, 0.16, 0.34, 0.05), P.stone("e3dccf" if i % 2 == 0 else "d8d0c2"), Vector3(cos(a) * 1.58, 0.62, sin(a) * 1.58), Vector3(0, -a + PI / 2, 0))
	_add(g, P.cyl(0.42, 0.5, 0.3, 16), P.stone(P.STONE), Vector3(0, 0.6, 0))
	_add(g, P.cyl(0.2, 0.28, 1.2, 16), P.stone(P.STONE), Vector3(0, 1.2, 0))
	_add(g, P.torus(0.24, 0.05, 16), P.stone("e3dccf"), Vector3(0, 1.0, 0))
	_add(g, P.cyl(0.78, 0.3, 0.28, 24), P.stone(P.STONE), Vector3(0, 1.72, 0))
	_add(g, P.torus(0.77, 0.05, 24), P.stone("e3dccf"), Vector3(0, 1.86, 0))
	var topper := _add(g, P.sphere(0.22, 4, 2), P.unique_mat("c9a8ff", "7a5cff", 0.0), Vector3(0, 2.15, 0)); topper.name = "topper"
	var pool := _add(g, P.cyl(1.42, 1.42, 0.05, 24), P.glow_mat(Color("6fd8ee"), 0.85), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3.ONE, false); pool.name = "pool"; pool.visible = false
	var bw := _add(g, P.cyl(0.66, 0.66, 0.04, 16), P.glow_mat(Color("6fd8ee"), 0.85), Vector3(0, 1.82, 0), Vector3.ZERO, Vector3.ONE, false); bw.name = "bowlWater"; bw.visible = false
	var cracks := Node3D.new(); cracks.name = "cracks"; g.add_child(cracks)
	for n in 6:
		var a := n * 1.1
		_add(cracks, P.cone(0.12, 0.4, 4), P.mat("8a9a5a"), Vector3(cos(a) * 1.2, 0.75, sin(a) * 1.2), Vector3(0, 0, sin(a) * 0.4))
	var jets := Node3D.new(); jets.name = "jets"; jets.visible = false; g.add_child(jets)
	var jm := P.glow_mat(Color("c9f6ff"), 0.7)
	for n in 6: var d := _add(jets, P.sphere(0.07, 6, 4), jm, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false); d.set_meta("phase", n / 6.0); d.set_meta("ring", false)
	for n in 8: var d := _add(jets, P.sphere(0.06, 6, 4), jm, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false); d.set_meta("phase", n / 8.0); d.set_meta("ring", true)
	_add(g, P.cyl(0.16, 0.16, 0.5, 10), P.mat("8a8f9a"), Vector3(1.9, 0.35, 0.5), Vector3(0, 0, PI / 2))
	return g

static func animate_fountain(g: Node3D, t: float, flowing: bool) -> void:
	var jets: Node3D = g.get_node("jets")
	jets.visible = flowing
	g.get_node("pool").visible = flowing
	g.get_node("bowlWater").visible = flowing
	g.get_node("cracks").visible = not flowing
	var topper: MeshInstance3D = g.get_node("topper")
	(topper.material_override as StandardMaterial3D).emission_energy_multiplier = 1.5 if flowing else 0.0
	if flowing: topper.rotation.y = t * 1.2
	if not flowing: return
	for d in jets.get_children():
		var ph: float = d.get_meta("phase")
		var p := fmod(t * 0.8 + ph, 1.0)
		if d.get_meta("ring"):
			var a := ph * TAU; var r := 0.3 + p * 0.5
			d.position = Vector3(cos(a) * r, 1.95 + sin(p * PI) * 0.35 - p * 0.15, sin(a) * r)
		else: d.position = Vector3(0, 2.2 + p * 0.6, 0)
		d.scale = Vector3.ONE * (1.0 - p * 0.5)

## A striped lighthouse on a stone plinth. Its lamp room lights and the beam sweeps round when its drive is powered
## (see animate_machine).
static func lighthouse(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var r := minf(b.w, b.d) / 2.0 - 0.15
	_add(g, P.cyl(r + 0.1, r + 0.3, 0.6, 22), P.stone("cfc6b6"), Vector3(0, 0.3, 0))
	for i in 4:
		var rt := r * (0.86 - i * 0.07); var rb := r * (0.93 - i * 0.07)
		_add(g, P.cyl(rt, rb, 1.5, 22), P.plaster("fffaf0" if i % 2 == 0 else "e0594f"), Vector3(0, 0.6 + i * 1.5 + 0.75, 0))
	var top := 6.6
	_add(g, P.cyl(r * 0.78, r * 0.7, 0.18, 22), P.mat("3e4f48"), Vector3(0, top + 0.09, 0))
	for i in 12:   # gallery railing
		var a := TAU * i / 12.0
		_add(g, P.cyl(0.03, 0.03, 0.5, 4), P.mat("3e4f48"), Vector3(cos(a) * r * 0.74, top + 0.43, sin(a) * r * 0.74))
	var lamp := _add(g, P.cyl(r * 0.42, r * 0.42, 1.0, 16), P.unique_mat(Color("fff6c8"), Color("ffd866"), 0.2), Vector3(0, top + 0.68, 0))
	lamp.name = "lamp"
	_add(g, P.cone(r * 0.6, 0.9, 16), P.mat(b.get("roof", "c94a44")), Vector3(0, top + 1.63, 0))
	_add(g, P.sphere(0.14, 8, 6), P.mat(P.GOLD), Vector3(0, top + 2.15, 0))
	var pivot := Node3D.new(); pivot.name = "beam"; pivot.position.y = top + 0.7; pivot.visible = false; g.add_child(pivot)
	var bm := P.glow_mat(Color(1.0, 0.95, 0.7), 0.28); bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1, 1]:
		var beam := P.mi(P.cyl(0.35, 1.6, 14.0, 10), bm, Vector3(side * 7.2, 0, 0), false); beam.rotation.z = side * PI / 2; pivot.add_child(beam)
	var li := OmniLight3D.new(); li.name = "light"; li.position.y = top + 0.7; li.omni_range = 16.0; li.light_color = Color("ffe9a8"); li.visible = false; g.add_child(li)
	var di := Interiors.door_info(b)
	var dp: Vector2 = di.out * (r * 0.93 + 0.02)
	var door := _add(g, P.box(0.9, 1.7, 0.08) if di.out.y != 0.0 else P.box(0.08, 1.7, 0.9), P.wood("7a4a2a"), Vector3(dp.x, 1.45, dp.y))
	door.name = "door"
	return g

## A stone clock tower with a face on each side; the hands turn once its drive is powered.
static func clocktower(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var w: float = b.w - 0.4
	_add(g, P.rbox(w + 0.3, 0.5, w + 0.3, 0.08), P.stone("bdb5a8"), Vector3(0, 0.25, 0))
	_add(g, P.rbox(w, 4.6, w, 0.1), P.stone(b.get("wall", "d9cdb8")), Vector3(0, 2.8, 0))
	_add(g, P.rbox(w * 0.86, 1.8, w * 0.86, 0.08), P.plaster("f4ecdf"), Vector3(0, 6.0, 0))
	var roof := _add(g, P.cone(w * 0.72, 1.8, 4), P.mat(b.get("roof", "5f7fd8")), Vector3(0, 7.8, 0)); roof.rotation.y = PI / 4
	_add(g, P.cyl(0.03, 0.03, 0.8, 4), P.mat("666666"), Vector3(0, 9.0, 0))
	var hands := Node3D.new(); hands.name = "hands"; g.add_child(hands)
	for k in 4:
		var a := k * PI / 2.0
		var face := Node3D.new(); face.position = Vector3(sin(a) * (w * 0.43 + 0.02), 6.0, cos(a) * (w * 0.43 + 0.02)); face.rotation.y = a; g.add_child(face)
		var disc := _add(face, P.cyl(0.62, 0.62, 0.06, 24), P.mat("fffaf0"), Vector3.ZERO); disc.rotation.x = PI / 2
		var rim := _add(face, P.torus(0.62, 0.05, 24), P.mat(P.GOLD), Vector3(0, 0, 0.02)); rim.rotation.x = PI / 2
		for m in [["minute", 0.5, 0.05], ["hour", 0.34, 0.07]]:
			var hp := Node3D.new(); hp.name = m[0]; hp.position.z = 0.05; face.add_child(hp)
			_add(hp, P.box(m[2], m[1], 0.02), P.mat("3a2e2a"), Vector3(0, m[1] / 2.0, 0))
			hp.set_meta("hand", m[0]); face.set_meta(m[0], hp)
		face.add_to_group("clock_face_%s" % b.id)
		g.set_meta("face%d" % k, face)
	var di := Interiors.door_info(b)
	var dp: Vector2 = di.out * (w / 2.0 + 0.02)
	_add(g, P.box(1.0, 1.9, 0.08) if di.out.y != 0.0 else P.box(0.08, 1.9, 1.0), P.wood("7a4a2a"), Vector3(dp.x, 1.45, dp.y))
	return g

## Lighthouse lamp and beam, clock hands: alive while their machine is fed.
static func animate_machine(o: Node3D, b: Dictionary, t: float, dt: float, on: bool, night: bool) -> void:
	match b.kind:
		"lighthouse":
			var lamp: MeshInstance3D = o.get_node("lamp")
			(lamp.material_override as StandardMaterial3D).emission_energy_multiplier = (2.6 + sin(t * 3.0) * 0.3) if on else 0.2
			var beam: Node3D = o.get_node("beam")
			beam.visible = on and night
			beam.rotation.y = t * 0.7
			(o.get_node("light") as OmniLight3D).visible = on and night
		"clocktower":
			if not on: return
			for k in 4:
				var face: Node3D = o.get_meta("face%d" % k)
				(face.get_meta("minute") as Node3D).rotation.z = -t * 0.6
				(face.get_meta("hour") as Node3D).rotation.z = -t * 0.05

static func lamp_post() -> Node3D:
	var g := Node3D.new()
	var iron := P.mat("3e4f48")
	_add(g, P.cyl(0.16, 0.2, 0.22, 10), iron, Vector3(0, 0.11, 0))
	_add(g, P.cyl(0.045, 0.06, 1.75, 8), iron, Vector3(0, 1.0, 0))
	_add(g, P.cyl(0.12, 0.08, 0.08, 8), iron, Vector3(0, 1.88, 0))
	var bulb := _add(g, P.cyl(0.11, 0.09, 0.3, 6), P.unique_mat("fff1b8", "ffcf6b", 0.2), Vector3(0, 2.07, 0)); bulb.name = "bulb"
	for a in 3: _add(g, P.box(0.025, 0.32, 0.025), iron, Vector3(cos(a * TAU / 3.0) * 0.11, 2.07, sin(a * TAU / 3.0) * 0.11))
	_add(g, P.cyl(0.03, 0.2, 0.16, 6), iron, Vector3(0, 2.3, 0))
	_add(g, P.sphere(0.04, 6, 4), iron, Vector3(0, 2.41, 0))
	var light := OmniLight3D.new(); light.name = "light"; light.position = Vector3(0, 2.0, 0)
	light.light_color = Color("ffc977"); light.omni_range = 6.0; light.omni_attenuation = 1.4; light.light_energy = 0.0; light.visible = false
	g.add_child(light)
	return g

static func fence(length: float = 2.0) -> Node3D:
	var g := Node3D.new()
	var x := 0.0
	while x <= length: _add(g, P.box(0.12, 0.8, 0.12), P.wood("f4e6d0"), Vector3(x - length / 2.0, 0.4, 0)); x += 1.0
	for y in [0.3, 0.6]: _add(g, P.box(length, 0.08, 0.06), P.wood("f4e6d0"), Vector3(0, y, 0))
	return g

static func broken_post() -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(0.16, 0.2, 1.3, 7), P.wood("8a6a50"), Vector3(0, -0.7, 0), Vector3(0, 0, 0.25))
	return g

static func cliff(w: float) -> Node3D:
	var g := Node3D.new()
	var n := int(ceil(w / 2.2))
	for i in n:
		var x := -w / 2.0 + (i + 0.5) * (w / n)
		_add(g, P.sphere(1.4, 6, 4), P.stone("b9a993" if i % 2 else "c8b9a2"), Vector3(x, 0.9 + (i % 3) * 0.25, 0), Vector3(0, i * 1.7, 0), Vector3(1.2, 1.1 + (i % 2) * 0.3, 0.9))
		if i % 2 == 0:
			var bu := bush(0.8, "5aa65a"); bu.position = Vector3(x, 2.2, 0.2); g.add_child(bu)
	return g

static func gate() -> Node3D:
	var g := Node3D.new()
	for x in [-2.6, 2.6]: _add(g, P.rbox(0.5, 2.6, 0.5, 0.06), P.stone(P.STONE), Vector3(x, 1.3, 0))
	var doors := Node3D.new(); doors.name = "doors"; g.add_child(doors)
	for s in [-1, 1]:
		var d := Node3D.new(); d.position.x = s * 2.35; d.set_meta("side", s)
		for n in 4: _add(d, P.box(0.14, 2, 0.1), P.wood("7a4a2a"), Vector3(-s * (0.3 + n * 0.55), 1.0, 0))
		_add(d, P.box(2.2, 0.14, 0.12), P.wood("7a4a2a"), Vector3(-s * 1.1, 1.5, 0))
		_add(d, P.box(2.2, 0.14, 0.12), P.wood("7a4a2a"), Vector3(-s * 1.1, 0.5, 0))
		doors.add_child(d)
	var seal := _add(g, P.torus(0.3, 0.07, 16), P.mat("ff6f91", "ff6f91", 0.6), Vector3(0, 1.4, 0.1), Vector3(PI / 2, 0, 0)); seal.name = "seal"
	return g

static func boat() -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(2.0, 0.8, 4.2, 0.35), P.mat("e8705a"), Vector3(0, 0.15, 0))
	_add(g, P.box(1.8, 0.08, 4.0), P.wood("e0b07a"), Vector3(0, 0.58, 0))
	_add(g, P.cyl(0.07, 0.08, 3.4, 6), P.wood("8b5a3c"), Vector3(0, 2.0, 0))
	_add(g, P.box(0.02, 2.2, 1.6), P.mat("fff7e8"), Vector3(0.05, 2.3, 0.15))
	_add(g, P.box(0.02, 0.3, 0.5), P.mat("5f9be0"), Vector3(0, 3.8, 0.25))
	return g

static func dig_spot() -> Node3D:
	var g := Node3D.new()
	_add(g, P.hemi(0.35, 8), P.mat("b88b5e"), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.4, 1))
	return g

static func fishing_spot() -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(0.55, 0.6, 0.12, 10), P.mat("c9a06e"), Vector3(0, 0.06, 0))
	return g

static func oak() -> Node3D:
	var g := round_tree(1.25, 0.2)
	var ac := Node3D.new(); ac.name = "acorns"
	for p in [[0.6, 0.5], [-0.5, 0.7], [0.3, -0.7]]: _add(ac, P.sphere(0.08, 6, 5), P.mat("9a6a3a"), Vector3(p[0], 0.05, p[1]))
	g.add_child(ac)
	return g

## Furniture that isn't a build piece, for interiors.
static func interior_prop(id: String) -> Node3D:
	var g := Node3D.new()
	match id:
		"oven":
			_add(g, P.rbox(0.9, 1.1, 0.8, 0.08), P.stone("c98a6a"), Vector3(0, 0.55, 0))
			_add(g, P.cyl(0.32, 0.32, 0.06, 18), P.mat("2a1a14"), Vector3(0, 0.55, 0.38), Vector3(PI / 2, 0, 0))
			_add(g, P.cyl(0.26, 0.26, 0.07, 18), P.unique_mat("ff9a40", "ff7a20", 1.4), Vector3(0, 0.52, 0.37), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.6))
			_add(g, P.cyl(0.12, 0.14, 0.8, 10), P.stone("b07a5a"), Vector3(0.2, 1.4, -0.15))
		"barrel":
			_add(g, P.cyl(0.3, 0.32, 0.8, 16), P.wood("a0623a"), Vector3(0, 0.4, 0))
			for y in [0.15, 0.65]: _add(g, P.torus(0.315, 0.02, 20), P.mat("4a4a5a"), Vector3(0, y, 0))
		"crate":
			_add(g, P.rbox(0.7, 0.6, 0.7, 0.03), P.wood("c49a6c"), Vector3(0, 0.3, 0))
			for s in [-1, 1]: _add(g, P.box(0.04, 0.6, 0.72), P.wood("9a6a45"), Vector3(s * 0.33, 0.3, 0))
		"throne":
			_add(g, P.rbox(1.1, 0.5, 0.9, 0.06), P.wood("b5733f"), Vector3(0, 0.25, 0))
			_add(g, P.rbox(1.0, 0.18, 0.8, 0.06), P.fabric("c0304a"), Vector3(0, 0.55, 0.02))
			_add(g, P.rbox(1.1, 1.6, 0.18, 0.08), P.wood("b5733f"), Vector3(0, 1.2, -0.38))
			_add(g, P.rbox(0.9, 1.2, 0.06, 0.05), P.fabric("c0304a"), Vector3(0, 1.15, -0.28))
			for x in [-0.55, 0.55]: _add(g, P.sphere(0.09, 12, 8), P.mat(P.GOLD), Vector3(x, 2.05, -0.38))
			_add(g, P.cone(0.16, 0.3, 5), P.mat(P.GOLD), Vector3(0, 2.15, -0.38))
		"banner":
			_add(g, P.box(0.06, 0.06, 1.0), P.mat(P.GOLD), Vector3(0, 3.1, 0))
			_add(g, P.box(0.04, 1.8, 0.8), P.fabric("5f7fd8"), Vector3(0, 2.15, 0))
			_add(g, P.sphere(0.12, 12, 8), P.mat(P.GOLD), Vector3(-0.04, 2.3, 0))
		"pillar":
			_add(g, P.cyl(0.25, 0.3, 4.0, 16), P.stone("eadfcd"), Vector3(0, 2.0, 0))
			_add(g, P.rbox(0.75, 0.2, 0.75, 0.04), P.stone("d8d0c2"), Vector3(0, 0.1, 0))
			_add(g, P.rbox(0.7, 0.2, 0.7, 0.04), P.stone("d8d0c2"), Vector3(0, 4.0, 0))
	return g

static func market_stall() -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(2.2, 0.9, 0.9, 0.05), P.wood("d9a066"), Vector3(0, 0.45, 0))
	for x in [-1, 1]: _add(g, P.cyl(0.05, 0.05, 2.2, 6), P.wood("8b5a3c"), Vector3(x, 1.1, -0.3))
	_add(g, P.box(2.5, 0.1, 1.3), P.mat("ff8fab"), Vector3(0, 2.2, 0), Vector3(0.2, 0, 0))
	for f in [[-0.6, "ffd84a"], [0.0, "7cc35a"], [0.6, "ff5a5f"]]: _add(g, P.sphere(0.16, 8, 6), P.mat(f[1]), Vector3(f[0], 1.0, 0.1))
	return g
