class_name Props
## Low-poly prop builders for Hearthglow Village. Each returns a Node3D centred on its footprint at ground level.
const P := preload("res://scripts/world/palette.gd")

static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadow: bool = true) -> MeshInstance3D:
	var m := P.mi(mesh, material, pos, shadow)
	m.rotation = rot; m.scale = scl
	parent.add_child(m)
	return m

static func round_tree(s: float = 1.0, hue: float = 0.5, fruit: bool = false) -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(0.16, 0.24, 1.3, 7), P.mat(P.TRUNK), Vector3(0, 0.65, 0))
	var leaf := P.LEAF
	leaf.h += (hue - 0.5) * 0.06; leaf.v += (hue - 0.5) * 0.08
	var lm := P.mat(leaf)
	for b in [[0, 1.85, 0, 0.95], [0.5, 1.55, 0.2, 0.62], [-0.45, 1.6, -0.15, 0.6], [0.05, 2.45, 0.05, 0.6]]:
		_add(g, P.sphere(b[3], 9, 7), lm, Vector3(b[0], b[1], b[2]))
	if fruit: add_fruit(g)
	g.scale = Vector3.ONE * s
	return g

static func add_fruit(tree: Node3D) -> Node3D:
	var f := Node3D.new(); f.name = "fruit"
	for p in [[0.7, 1.7, 0.5], [-0.6, 1.9, 0.6], [0.2, 1.4, -0.85], [-0.3, 2.4, -0.5], [0.8, 2.1, -0.3]]:
		_add(f, P.sphere(0.13, 8, 6), P.mat("ff5a5f"), Vector3(p[0], p[1], p[2]))
	tree.add_child(f)
	return f

static func bush(s: float = 1.0, color: String = "69bf5f") -> Node3D:
	var g := Node3D.new()
	for b in [[0, 0.3, 0, 0.45], [0.35, 0.25, 0.1, 0.32], [-0.3, 0.25, -0.1, 0.32]]: _add(g, P.sphere(b[3], 8, 6), P.mat(color), Vector3(b[0], b[1], b[2]))
	g.scale = Vector3.ONE * s
	return g

static func rock(rich: bool = false) -> Node3D:
	var g := Node3D.new()
	_add(g, P.sphere(0.8, 6, 4), P.mat(P.STONE), Vector3(0, 0.4, 0), Vector3(0.2, 0.5, 0.1), Vector3(1.1, 0.75, 0.95))
	_add(g, P.sphere(0.45, 6, 4), P.mat(P.STONE_DARK), Vector3(0.55, 0.25, 0.35), Vector3(0.4, 0, 0.2))
	var vein = P.mat("8fe9ff", "3fbfff", 1.2) if rich else P.mat("d9a066")
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
	_add(g, P.rbox(0.9, 0.45, 0.62, 0.05), P.mat("b5733f"), Vector3(0, 0.23, 0))
	var lid := Node3D.new(); lid.name = "lid"; lid.position = Vector3(0, 0.45, -0.31); g.add_child(lid)
	_add(lid, P.rbox(0.9, 0.22, 0.62, 0.08), P.mat("c98447"), Vector3(0, 0.1, 0.31))
	for x in [-0.3, 0.3]: _add(g, P.box(0.08, 0.47, 0.64), P.mat(P.GOLD), Vector3(x, 0.24, 0))
	_add(g, P.box(0.14, 0.16, 0.06), P.mat(P.GOLD), Vector3(0, 0.42, 0.33))
	return g

static func fragment() -> Node3D:
	var g := Node3D.new()
	_add(g, P.sphere(0.22, 4, 2), P.mat("c9a8ff", "9b6bff", 0.5), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.5, 1), false)
	return g

static func sign_post() -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(0.06, 0.07, 1.1, 6), P.mat(P.WOOD_DARK), Vector3(0, 0.55, 0))
	_add(g, P.rbox(1.0, 0.55, 0.1, 0.04), P.mat(P.WOOD), Vector3(0, 1.05, 0))
	return g

static func notice_board() -> Node3D:
	var g := Node3D.new()
	for x in [-0.6, 0.6]: _add(g, P.cyl(0.07, 0.08, 1.7, 6), P.mat(P.WOOD_DARK), Vector3(x, 0.85, 0))
	_add(g, P.rbox(1.4, 0.9, 0.1, 0.04), P.mat("d9a066"), Vector3(0, 1.2, 0))
	for n in [[-0.35, 1.3, "fff7e0"], [0.25, 1.15, "ffe0ec"], [-0.1, 0.98, "e0f4ff"]]: _add(g, P.box(0.4, 0.3, 0.01), P.mat(n[2]), Vector3(n[0], n[1], 0.06), Vector3.ZERO, Vector3.ONE, false)
	_add(g, P.box(1.6, 0.08, 0.3), P.mat("c25b4a"), Vector3(0, 1.72, 0))
	return g

static func wardrobe() -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(0.9, 1.7, 0.5, 0.06), P.mat("e9b3c9"), Vector3(0, 0.85, 0))
	_add(g, P.box(0.55, 1.1, 0.01), P.glow_mat(Color("cfefff")), Vector3(0, 0.95, 0.26))
	_add(g, P.cone(0.55, 0.3, 4), P.mat("d48aab"), Vector3(0, 1.85, 0), Vector3(0, PI / 4, 0))
	return g

static func _window() -> Node3D:
	var w := Node3D.new()
	_add(w, P.rbox(0.8, 0.8, 0.1, 0.04), P.mat("ffffff"), Vector3.ZERO)
	var glass := _add(w, P.box(0.62, 0.62, 0.02), P.unique_mat("9fdcff", "ffcf6b", 0.0), Vector3(0, 0, 0.055), Vector3.ZERO, Vector3.ONE, false)
	glass.name = "glass"
	_add(w, P.box(0.06, 0.62, 0.02), P.mat("ffffff"), Vector3(0, 0, 0.06))
	return w

static func _on_side(obj: Node3D, b: Dictionary, side: String, y: float, offset: float = 0.0, out: float = 0.02) -> void:
	var hw: float = b.w / 2.0 + out
	var hd: float = b.d / 2.0 + out
	match side:
		"S": obj.position = Vector3(offset, y, hd)
		"N": obj.position = Vector3(offset, y, -hd); obj.rotation.y = PI
		"E": obj.position = Vector3(hw, y, offset); obj.rotation.y = PI / 2
		"W": obj.position = Vector3(-hw, y, offset); obj.rotation.y = -PI / 2

static func _door(g: Node3D, b: Dictionary, color: String = "a0623a") -> void:
	var door := Node3D.new()
	_add(door, P.rbox(1.0, 1.6, 0.12, 0.05), P.mat(color), Vector3.ZERO)
	_add(door, P.sphere(0.05, 6, 5), P.mat(P.GOLD), Vector3(0.3, 0, 0.08))
	_on_side(door, b, b.door, 0.8, float(b.get("doorOffset", 0)))
	g.add_child(door)

static func _gable(w: float, d: float, y: float, color) -> MeshInstance3D:
	var big := maxf(w, d)
	var roof := P.mi(P.cyl(0.01, big / 2.0 * 1.2, 1.8, 4), P.mat(color), Vector3(0, y, 0))
	roof.rotation.y = PI / 4
	roof.scale = Vector3(w / big, 1, d / big)
	return roof

static func cottage(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := 2.4
	_add(g, P.rbox(b.w, h, b.d, 0.12), P.mat(b.wall), Vector3(0, h / 2.0, 0))
	_add(g, P.box(b.w + 0.2, 0.25, b.d + 0.2), P.mat(P.STONE_DARK), Vector3(0, 0.12, 0))
	var roof := _gable(b.w, b.d, h + 0.9, b.roof)
	# rotate the scaled pyramid properly: put it in a parent so scale applies after the 45° turn
	var holder := Node3D.new(); holder.scale = roof.scale; roof.scale = Vector3.ONE; roof.position.y = 0; holder.position.y = h + 0.9; holder.add_child(roof); g.add_child(holder)
	_add(g, P.box(0.5, 1.2, 0.5), P.mat("c97a5a"), Vector3(b.w * 0.25, h + 1.1, -b.d * 0.15))
	g.set_meta("chimney", Vector3(b.w * 0.25, h + 1.8, -b.d * 0.15))
	_door(g, b)
	var glasses: Array = []
	for s in ["N", "S", "E", "W"]:
		if s == b.door: continue
		var long: float = b.w if s in ["N", "S"] else b.d
		for off in ([-long * 0.25, long * 0.25] if long > 4.5 else [0.0]):
			var w := _window(); _on_side(w, b, s, 1.45, off); g.add_child(w); glasses.append(w.get_node("glass"))
	if b.door in ["N", "S"]:
		for off in [-b.w * 0.3, b.w * 0.3]:
			var w := _window(); _on_side(w, b, b.door, 1.45, off); g.add_child(w); glasses.append(w.get_node("glass"))
	g.set_meta("glasses", glasses)
	if b.has("awning"):
		var aw := Node3D.new(); _on_side(aw, b, b.door, 2.05, 0, 0.35)
		_add(aw, P.box(b.w * 0.8, 0.12, 0.8), P.mat(b.awning), Vector3(0, 0, 0), Vector3(-0.35, 0, 0))
		g.add_child(aw)
	return g

static func workshop(b: Dictionary) -> Node3D:
	var g := Node3D.new(); var h := 2.6; var t := 0.35
	var hw: float = b.w / 2.0; var hd: float = b.d / 2.0
	var wall_mat := P.unique_mat(b.wall)
	var g0: float = b.doorAt - b.z - b.doorWidth / 2.0
	var g1: float = b.doorAt - b.z + b.doorWidth / 2.0
	var walls := Node3D.new(); walls.name = "walls"; g.add_child(walls)
	var addw := func(w: float, d: float, x: float, z: float): _add(walls, P.box(w, h, d), wall_mat, Vector3(x, h / 2.0, z))
	addw.call(b.w, t, 0.0, -hd + t / 2.0); addw.call(b.w, t, 0.0, hd - t / 2.0); addw.call(t, b.d, -hw + t / 2.0, 0.0)
	addw.call(t, g0 + hd, hw - t / 2.0, (-hd + g0) / 2.0); addw.call(t, hd - g1, hw - t / 2.0, (g1 + hd) / 2.0)
	_add(walls, P.box(t, h - 1.9, g1 - g0), wall_mat, Vector3(hw - t / 2.0, 1.9 + (h - 1.9) / 2.0, (g0 + g1) / 2.0))
	_add(g, P.box(b.w - 0.2, 0.06, b.d - 0.2), P.mat("d9b48a"), Vector3(0, 0.03, 0))
	var x := -hw + 0.6
	while x < hw:
		_add(g, P.box(0.03, 0.065, b.d - 0.3), P.mat("c49a6c"), Vector3(x, 0.035, 0), Vector3.ZERO, Vector3.ONE, false); x += 0.9
	var roof_mat := P.unique_mat(b.roof)
	roof_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var roof := Node3D.new(); roof.name = "roof"; g.add_child(roof)
	var big := maxf(b.w, b.d)
	var holder := Node3D.new(); holder.scale = Vector3(b.w / big, 1, b.d / big); holder.position.y = h + 1.0; roof.add_child(holder)
	var rp := P.mi(P.cyl(0.01, big / 2.0 * 1.22, 2.0, 4), roof_mat, Vector3.ZERO); rp.rotation.y = PI / 4; holder.add_child(rp)
	_add(roof, P.box(b.w, 0.1, b.d), roof_mat, Vector3(0, h + 0.05, 0))
	g.set_meta("roof_mat", roof_mat)
	_add(g, P.rbox(1.6, 0.5, 0.1, 0.05), P.mat("8b5a3c"), Vector3(hw + 0.1, 2.25, b.doorAt - b.z - 1.6), Vector3(0, PI / 2, 0))
	var gear := _add(g, P.torus(0.22, 0.07, 10), P.mat(P.GOLD), Vector3(hw + 0.17, 2.25, b.doorAt - b.z - 1.6), Vector3(0, 0, PI / 2))
	gear.name = "signGear"
	for off in [-1.8, 1.8]: var w := _window(); _on_side(w, b, "S", 1.5, off); g.add_child(w)
	for off in [-2.0, 2.0]: var w := _window(); _on_side(w, b, "N", 1.5, off); g.add_child(w)
	var clutter := Node3D.new(); clutter.name = "clutter"; g.add_child(clutter)
	for c in [[-3.3, -2.4, 0.6], [-3.6, 2.4, 0.5], [2.6, 2.6, 0.55]]: _add(clutter, P.rbox(c[2], c[2], c[2], 0.04), P.mat("a88a6a"), Vector3(c[0], c[2] / 2.0, c[1]), Vector3(0, c[0], 0))
	for c in [[-hw + 0.4, -hd + 0.4, 0.8], [-hw + 0.4, hd - 0.4, -0.8]]: _add(clutter, P.box(0.8, 0.6, 0.01), P.glow_mat(Color("e8e8e8"), 0.5), Vector3(c[0], 2.3, c[1]), Vector3(0, c[2], 0), Vector3.ONE, false)
	return g

static func caravan(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(b.w, 1.7, b.d, 0.3), P.mat(b.wall), Vector3(0, 1.35, 0))
	_add(g, P.cyl(b.d / 2.0 + 0.15, b.d / 2.0 + 0.15, b.w + 0.2, 14), P.mat(b.roof), Vector3(0, 2.15, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.9))
	for p in [[-1.2, b.d / 2.0], [1.2, b.d / 2.0], [-1.2, -b.d / 2.0], [1.2, -b.d / 2.0]]: _add(g, P.torus(0.35, 0.08, 12), P.mat("8b5a3c"), Vector3(p[0], 0.38, p[1]), Vector3(PI / 2, 0, 0))
	_add(g, P.cyl(0.12, 0.12, 0.7), P.mat("555555"), Vector3(1.3, 2.9, 0))
	var cog := _add(g, P.torus(0.3, 0.09, 8), P.mat(P.GOLD), Vector3(0, 1.5, b.d / 2.0 + 0.05), Vector3(PI / 2, 0, 0)); cog.name = "cog"
	_door(g, b, "7a4a8a")
	return g

static func castle(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(b.w - 2, 4.2, b.d - 2, 0.15), P.mat(b.wall), Vector3(0, 2.1, 0))
	var wall_h := 2.4
	_add(g, P.rbox(b.w, wall_h, b.d, 0.12), P.mat("eadfcd"), Vector3(0, wall_h / 2.0, 0))
	var x: float = -b.w / 2.0 + 0.4
	while x <= b.w / 2.0 - 0.4:
		for z in [-b.d / 2.0, b.d / 2.0]: _add(g, P.box(0.45, 0.45, 0.4), P.mat("eadfcd"), Vector3(x, wall_h + 0.22, z))
		x += 0.9
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var tx: float = c[0] * b.w / 2.0; var tz: float = c[1] * b.d / 2.0
		_add(g, P.cyl(1.0, 1.1, 5.2, 14), P.mat(b.wall), Vector3(tx, 2.6, tz))
		_add(g, P.cone(1.3, 2.2, 14), P.mat(b.roof), Vector3(tx, 6.3, tz))
		_add(g, P.cyl(0.03, 0.03, 0.9, 4), P.mat("666666"), Vector3(tx, 7.8, tz))
		_add(g, P.box(0.6, 0.35, 0.02), P.mat("ff6f91"), Vector3(tx + 0.3, 8.05, tz))
	var kr := P.mi(P.cone((b.w - 2) * 0.62, 2.6, 4), P.mat(b.roof), Vector3.ZERO); kr.rotation.y = PI / 4
	var kh := Node3D.new(); kh.position.y = 5.5; kh.scale = Vector3(1, 1, (b.d - 2) / (b.w - 2)); kh.add_child(kr); g.add_child(kh)
	_add(g, P.rbox(0.15, 2.0, 1.6, 0.06), P.mat("7a4a2a"), Vector3(-b.w / 2.0 - 0.05, 1.0, 0))
	_add(g, P.torus(0.8, 0.12, 12), P.mat(P.STONE_DARK), Vector3(-b.w / 2.0 - 0.08, 1.8, 0), Vector3(0, PI / 2, 0), Vector3(1, 1, 1))
	_add(g, P.box(0.02, 1.6, 0.9), P.mat("ff6f91"), Vector3(-b.w / 2.0 - 0.08, 3.4, 0))
	_add(g, P.sphere(0.25, 4, 2), P.mat(P.GOLD), Vector3(-b.w / 2.0 - 0.12, 3.5, 0))
	for z in [-2.2, 2.2]: var w := _window(); w.position = Vector3(-b.w / 2.0 - 0.02, 1.5, z); w.rotation.y = -PI / 2; g.add_child(w)
	return g

static func fountain() -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(1.7, 1.85, 0.6, 24), P.mat(P.STONE), Vector3(0, 0.3, 0))
	_add(g, P.cyl(1.45, 1.45, 0.62, 24), P.mat("b8b0a4"), Vector3(0, 0.32, 0))
	_add(g, P.cyl(0.25, 0.35, 1.4, 12), P.mat(P.STONE), Vector3(0, 1.0, 0))
	_add(g, P.cyl(0.75, 0.35, 0.3, 16), P.mat(P.STONE), Vector3(0, 1.7, 0))
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

static func lamp_post() -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(0.06, 0.09, 2.2, 8), P.mat("4a4a5a"), Vector3(0, 1.1, 0))
	var bulb := _add(g, P.sphere(0.2, 10, 8), P.unique_mat("fff3b0", "ffcf6b", 0.2), Vector3(0, 2.3, 0)); bulb.name = "bulb"
	_add(g, P.cone(0.28, 0.2, 8), P.mat("4a4a5a"), Vector3(0, 2.5, 0))
	return g

static func fence(length: float = 2.0) -> Node3D:
	var g := Node3D.new()
	var x := 0.0
	while x <= length: _add(g, P.box(0.12, 0.8, 0.12), P.mat("f4e6d0"), Vector3(x - length / 2.0, 0.4, 0)); x += 1.0
	for y in [0.3, 0.6]: _add(g, P.box(length, 0.08, 0.06), P.mat("f4e6d0"), Vector3(0, y, 0))
	return g

static func broken_post() -> Node3D:
	var g := Node3D.new()
	_add(g, P.cyl(0.16, 0.2, 1.3, 7), P.mat("8a6a50"), Vector3(0, -0.7, 0), Vector3(0, 0, 0.25))
	return g

static func cliff(w: float) -> Node3D:
	var g := Node3D.new()
	var n := int(ceil(w / 2.2))
	for i in n:
		var x := -w / 2.0 + (i + 0.5) * (w / n)
		_add(g, P.sphere(1.4, 6, 4), P.mat("b9a993" if i % 2 else "c8b9a2"), Vector3(x, 0.9 + (i % 3) * 0.25, 0), Vector3(0, i * 1.7, 0), Vector3(1.2, 1.1 + (i % 2) * 0.3, 0.9))
		if i % 2 == 0:
			var bu := bush(0.8, "5aa65a"); bu.position = Vector3(x, 2.2, 0.2); g.add_child(bu)
	return g

static func gate() -> Node3D:
	var g := Node3D.new()
	for x in [-2.6, 2.6]: _add(g, P.rbox(0.5, 2.6, 0.5, 0.06), P.mat(P.STONE), Vector3(x, 1.3, 0))
	var doors := Node3D.new(); doors.name = "doors"; g.add_child(doors)
	for s in [-1, 1]:
		var d := Node3D.new(); d.position.x = s * 2.35; d.set_meta("side", s)
		for n in 4: _add(d, P.box(0.14, 2, 0.1), P.mat("7a4a2a"), Vector3(-s * (0.3 + n * 0.55), 1.0, 0))
		_add(d, P.box(2.2, 0.14, 0.12), P.mat("7a4a2a"), Vector3(-s * 1.1, 1.5, 0))
		_add(d, P.box(2.2, 0.14, 0.12), P.mat("7a4a2a"), Vector3(-s * 1.1, 0.5, 0))
		doors.add_child(d)
	var seal := _add(g, P.torus(0.3, 0.07, 16), P.mat("ff6f91", "ff6f91", 0.6), Vector3(0, 1.4, 0.1), Vector3(PI / 2, 0, 0)); seal.name = "seal"
	return g

static func boat() -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(2.0, 0.8, 4.2, 0.35), P.mat("e8705a"), Vector3(0, 0.15, 0))
	_add(g, P.box(1.8, 0.08, 4.0), P.mat("e0b07a"), Vector3(0, 0.58, 0))
	_add(g, P.cyl(0.07, 0.08, 3.4, 6), P.mat("8b5a3c"), Vector3(0, 2.0, 0))
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

static func market_stall() -> Node3D:
	var g := Node3D.new()
	_add(g, P.rbox(2.2, 0.9, 0.9, 0.05), P.mat("d9a066"), Vector3(0, 0.45, 0))
	for x in [-1, 1]: _add(g, P.cyl(0.05, 0.05, 2.2, 6), P.mat("8b5a3c"), Vector3(x, 1.1, -0.3))
	_add(g, P.box(2.5, 0.1, 1.3), P.mat("ff8fab"), Vector3(0, 2.2, 0), Vector3(0.2, 0, 0))
	for f in [[-0.6, "ffd84a"], [0.0, "7cc35a"], [0.6, "ff5a5f"]]: _add(g, P.sphere(0.16, 8, 6), P.mat(f[1]), Vector3(f[0], 1.0, 0.1))
	return g
