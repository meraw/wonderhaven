extends RefCounted

const P := preload("../../world/palette.gd")
const Palazzo := preload("palazzo.gd")

static func dress(village: Node3D, height: Callable, lanes: Array, rail: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "port_scenery"
	village.add_child(root)
	steps(root, height, lanes)
	parapets(root, height)
	rails(root)
	railway(root, rail)
	laundry(root)
	for pr in Data.layout.get("props", []):
		var kind := String(pr.kind)
		if not kind.begins_with("port_"): continue
		var y: float = float(pr.y) if pr.has("y") else float(height.call(float(pr.x), float(pr.z)))
		var o := prop(kind, pr)
		if o == null: continue
		o.position = Vector3(float(pr.x), y, float(pr.z))
		o.rotation.y = float(pr.get("r", 0.0))
		o.name = String(pr.get("id", kind))
		root.add_child(o)

static func steps(root: Node3D, height: Callable, lanes: Array) -> void:
	var parts := HouseKit.Parts.new(root)
	var mat := Palazzo.tinted("stone")
	for lane in lanes:
		var r: Rect2 = lane
		var x := r.get_center().x
		var z := r.position.y
		while z < r.end.y - 0.01:
			var h0 := float(height.call(x, z))
			var run := 0.24
			var z1 := minf(z + run, r.end.y)
			var h1 := float(height.call(x, z1))
			var top := maxf(h0, h1)
			var bottom := minf(h0, h1) - 0.08
			var t := 0.88 + 0.12 * absf(sin(z * 3.7))
			parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(r.size.x, top - bottom, z1 - z)), Vector3(x, (top + bottom) / 2.0, (z + z1) / 2.0)), false, mat, Color(0.78 * t, 0.74 * t, 0.68 * t))
			parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(r.size.x, 0.04, 0.06)), Vector3(x, top + 0.005, z if h0 > h1 else z1)), false, mat, Color(0.62, 0.42, 0.34))
			z = z1
	parts.flush()

static func parapets(root: Node3D, height: Callable) -> void:
	var stone := P.stone("9a958c")
	for c in Data.layout.get("harbor_cliffs", []):
		var w := float(c.maxX) - float(c.minX)
		var d := float(c.maxZ) - float(c.minZ)
		var x := (float(c.minX) + float(c.maxX)) / 2.0
		var z := (float(c.minZ) + float(c.maxZ)) / 2.0
		var y := float(height.call(x, z))
		var wall := P.mi(P.box(w, 1.0, d), stone, Vector3(x, y + 0.5, z))
		wall.name = "port_parapet"
		root.add_child(wall)
		root.add_child(P.mi(P.box(w + 0.1, 0.1, d + 0.1), P.stone("bdb7ab"), Vector3(x, y + 1.05, z)))

static func rails(root: Node3D) -> void:
	var iron := P.mat("2f3330")
	for f in Data.layout.get("floors", []):
		if not String(f.id).begins_with("port_rail"): continue
		var r: Array = f.rect
		var x0 := minf(r[0], r[2]); var x1 := maxf(r[0], r[2])
		var z0 := minf(r[1], r[3]); var z1 := maxf(r[1], r[3])
		var y := float(f.get("bottom", float(f.top) - 1.0))
		var top := float(f.top)
		var along_x := (x1 - x0) >= (z1 - z0)
		var length := (x1 - x0) if along_x else (z1 - z0)
		var cx := (x0 + x1) / 2.0
		var cz := (z0 + z1) / 2.0
		var bar := Vector3(length, 0.06, 0.06) if along_x else Vector3(0.06, 0.06, length)
		root.add_child(P.mi(P.box(bar.x, bar.y, bar.z), iron, Vector3(cx, top - 0.1, cz)))
		root.add_child(P.mi(P.box(bar.x, bar.y, bar.z), iron, Vector3(cx, y + 0.12, cz)))
		var n := maxi(2, int(length / 0.14))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = P.box(0.025, top - y - 0.1, 0.025)
		mm.instance_count = n + 1
		for i in n + 1:
			var u := -length / 2.0 + length * i / n
			var p := Vector3(cx + (u if along_x else 0.0), (top + y) / 2.0 - 0.05, cz + (0.0 if along_x else u))
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = iron
		root.add_child(mmi)

static func railway(root: Node3D, rail: Dictionary) -> void:
	var z := float(rail.z)
	var x0 := float(rail.x0)
	var x1 := float(rail.x1)
	var y := float(rail.y)
	var steel := P.mat("6f6a64")
	var sleepers := HouseKit.Parts.new(root)
	var wood := Palazzo.tinted("wood")
	var x := x0
	while x < x1:
		sleepers.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(0.26, 0.12, 2.5)), Vector3(x, y + 0.06, z)), false, wood, Color("6a5440"))
		x += 0.65
	sleepers.flush()
	for s in [-0.72, 0.72]:
		root.add_child(P.mi(P.box(x1 - x0, 0.12, 0.08), steel, Vector3((x0 + x1) / 2.0, y + 0.18, z + s)))
	var dark := P.mat("15130f")
	var rock := P.stone("8f897c")
	for end in [[x0, 1.0, "w"], [x1, -1.0, "e"]]:
		var px: float = end[0]
		var face: float = end[1]
		var tag: String = end[2]
		root.add_child(P.mi(P.box(0.6, 6.2, 6.6), rock, Vector3(px + face * 0.1, y + 3.1, z)))
		var mouth := P.mi(P.box(0.2, 4.6, 4.2), dark, Vector3(px + face * 0.45, y + 2.3, z))
		mouth.name = "port_tunnel_" + tag
		root.add_child(mouth)
		root.add_child(P.mi(P.cyl(2.1, 2.1, 0.2, 16), dark, Vector3(px + face * 0.45, y + 4.6, z), false))
		var arch := P.mi(P.box(0.3, 0.5, 5.2), P.stone("bdb7ab"), Vector3(px + face * 0.55, y + 6.9, z))
		root.add_child(arch)

static func laundry(root: Node3D) -> void:
	var line := P.mat("e8e4dc")
	var peg := P.wood("c49a6c")
	for l in Data.layout.get("port_lines", []):
		var a := Vector3(float(l[0]), float(l[4]), float(l[1]))
		var c := Vector3(float(l[2]), float(l[4]), float(l[3]))
		var mid := (a + c) / 2.0 + Vector3(0, -0.25, 0)
		for seg in [[a, mid], [mid, c]]:
			var p0: Vector3 = seg[0]
			var p1: Vector3 = seg[1]
			var length := p0.distance_to(p1)
			var m := P.mi(P.cyl(0.012, 0.012, length, 4), line, (p0 + p1) / 2.0, false)
			m.transform = Transform3D(Basis(Quaternion(Vector3.UP, (p1 - p0).normalized())), (p0 + p1) / 2.0)
			root.add_child(m)
		for k in 3:
			var t := 0.2 + k * 0.3
			var p := a.lerp(c, t) + Vector3(0, -0.25 * (1.0 - absf(t - 0.5) * 2.0) - 0.04, 0)
			root.add_child(P.mi(P.box(0.03, 0.08, 0.02), peg, p, false))

static func prop(kind: String, pr: Dictionary) -> Node3D:
	match kind:
		"port_palm": return palm(int(absf(float(pr.x) * 13.0)))
		"port_pine": return umbrella_pine(int(absf(float(pr.z) * 7.0)))
		"port_holm": return holm_oak(int(absf(float(pr.x) * 3.0 + float(pr.z))))
		"port_mimosa": return mimosa(int(absf(float(pr.x) * 5.0)))
		"port_pillar": return pillar(float(pr.get("h", Palazzo.GROUND - 0.5)))
		"port_gozzo": return gozzo(String(pr.get("color", "f2efe6")), String(pr.get("trim", "2f6fa0")))
		"port_lampara": return lampara()
		"port_rowboat": return rowboat()
		"port_bollard": return bollard()
		"port_mooring": return mooring()
		"port_rubble": return rubble(int(absf(float(pr.z) * 11.0)))
		"port_payphone": return payphone()
		"port_cannon": return cannon()
		"port_balcony": return nonna_balcony(float(pr.get("w", 3.0)), float(pr.get("drop", 9.0)))
		"port_fishboxes": return fish_boxes()
		"port_capers": return capers(int(absf(float(pr.x) * 17.0 + float(pr.z))))
		"port_flagmast": return flagmast()
	return null

static func _leaf(color: String) -> StandardMaterial3D: return Props.leaf_mat(Color(color))

static func palm(seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lean := rng.randf_range(-0.12, 0.12)
	var bark := P.wood("8a7458")
	var pos := Vector3.ZERO
	for k in 8:
		var seg := Props._add(g, P.cyl(0.17, 0.2, 0.95, 8), bark, pos + Vector3(0, 0.47, 0), Vector3(0, 0, lean * k * 0.15))
		seg.name = "trunk"
		pos += Vector3(-sin(lean * k * 0.15) * 0.95, 0.95 * cos(lean * k * 0.15), 0)
	var fronds := P.mat("4f7a3a")
	for k in 9:
		var a := k * TAU / 9.0 + rng.randf()
		var frond := Props._add(g, P.box(0.5, 0.05, 2.4), fronds, pos + Vector3(sin(a) * 1.0, 0.1, cos(a) * 1.0), Vector3(0.55, a, 0))
		frond.name = "frond"
	Props._add(g, P.sphere(0.35, 8, 6), P.mat("6b5a3a"), pos)
	return g

static func umbrella_pine(seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hgt := rng.randf_range(6.5, 8.5)
	var bark := P.wood("7a5a42")
	Props._add(g, P.cyl(0.2, 0.32, hgt, 9), bark, Vector3(0, hgt / 2.0, 0), Vector3(0, 0, rng.randf_range(-0.08, 0.08)))
	Props._add(g, P.cyl(0.1, 0.14, 2.2, 6), bark, Vector3(0.7, hgt - 0.6, 0), Vector3(0, 0, -0.9))
	Props._add(g, P.cyl(0.1, 0.14, 2.0, 6), bark, Vector3(-0.6, hgt - 0.5, 0.2), Vector3(0.2, 0, 0.9))
	var mat := _leaf("4a6a34")
	Props._add(g, Foliage.canopy(seed % 2), mat, Vector3(0, hgt + 0.4, 0), Vector3(0, rng.randf() * TAU, 0), Vector3(3.2, 0.95, 3.0))
	Props._add(g, Foliage.canopy((seed + 1) % 2), mat, Vector3(1.0, hgt + 0.2, 0.6), Vector3(0, rng.randf() * TAU, 0), Vector3(1.8, 0.7, 1.7))
	return g

static func holm_oak(seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	Props._add(g, P.cyl(0.18, 0.3, 2.2, 8), P.wood("5e4632"), Vector3(0, 1.1, 0))
	var mat := _leaf("3e5232")
	Props._add(g, Foliage.canopy(seed % 2), mat, Vector3(0, 3.4, 0), Vector3(0, rng.randf() * TAU, 0), Vector3(2.1, 1.8, 2.1))
	return g

static func mimosa(seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	Props._add(g, P.cyl(0.1, 0.17, 2.0, 7), P.wood("6e5a46"), Vector3(0, 1.0, 0))
	Props._add(g, Foliage.canopy(seed % 2), _leaf("e8c53a"), Vector3(0, 2.8, 0), Vector3(0, rng.randf() * TAU, 0), Vector3(1.6, 1.3, 1.6))
	Props._add(g, Foliage.canopy((seed + 1) % 2), _leaf("f5e27a"), Vector3(0.5, 3.2, -0.3), Vector3(0, rng.randf() * TAU, 0), Vector3(0.9, 0.8, 0.9))
	Props._add(g, Foliage.canopy(seed % 2), _leaf("8a9a5a"), Vector3(-0.4, 2.5, 0.4), Vector3(0, rng.randf() * TAU, 0), Vector3(0.9, 0.7, 0.9))
	return g

static func pillar(h: float) -> Node3D:
	var g := Node3D.new()
	var stone := P.stone("b8b0a2")
	Props._add(g, P.box(0.62, 0.3, 0.62), stone, Vector3(0, 0.15, 0))
	Props._add(g, P.cyl(0.24, 0.27, h - 0.6, 12), stone, Vector3(0, 0.3 + (h - 0.6) / 2.0, 0))
	Props._add(g, P.box(0.66, 0.3, 0.66), stone, Vector3(0, h - 0.15, 0))
	return g

static func gozzo(color: String, trim: String) -> Node3D:
	var g := Node3D.new()
	Props._add(g, P.rbox(1.7, 0.75, 5.2, 0.3), P.mat(color), Vector3(0, -0.1, 0))
	Props._add(g, P.box(1.74, 0.12, 5.1), P.mat(trim), Vector3(0, 0.25, 0))
	Props._add(g, P.box(1.4, 0.06, 4.6), P.wood("b98a5a"), Vector3(0, 0.22, 0))
	Props._add(g, P.cone(0.22, 0.9, 6), P.mat(color), Vector3(0, 0.5, 2.6), Vector3(PI / 2.0 + 0.4, 0, 0))
	for k in 2: Props._add(g, P.box(1.3, 0.05, 0.2), P.wood("8a6a4a"), Vector3(0, 0.3, -1.0 + k * 1.6))
	return g

static func lampara() -> Node3D:
	var g := gozzo("2f5f8a", "f2efe6")
	Props._add(g, P.cyl(0.05, 0.06, 2.6, 6), P.mat("3a3a3a"), Vector3(0, 1.5, 1.6))
	Props._add(g, P.box(1.6, 0.06, 0.06), P.mat("3a3a3a"), Vector3(0, 2.75, 1.6))
	var lamp := Props._add(g, P.sphere(0.32, 10, 8), P.unique_mat("fff2c8", "ffd27a", 0.0), Vector3(0.75, 2.5, 1.6))
	lamp.name = "lampara_lamp"
	Props._add(g, P.box(0.9, 0.7, 1.1), P.mat("e8e4dc"), Vector3(0, 0.65, -1.2))
	return g

static func rowboat() -> Node3D:
	var g := Node3D.new()
	Props._add(g, P.rbox(1.2, 0.5, 3.2, 0.22), P.mat("c8302c"), Vector3(0, -0.12, 0))
	Props._add(g, P.box(1.0, 0.05, 3.0), P.wood("b98a5a"), Vector3(0, 0.08, 0))
	for s in [-1.0, 1.0]: Props._add(g, P.box(0.06, 0.04, 2.0), P.wood("8a6a4a"), Vector3(s * 0.45, 0.2, 0.2), Vector3(0, s * 0.25, 0))
	return g

static func bollard() -> Node3D:
	var g := Node3D.new()
	Props._add(g, P.cyl(0.16, 0.2, 0.55, 10), P.mat("3a3a3a"), Vector3(0, 0.27, 0))
	Props._add(g, P.cyl(0.22, 0.22, 0.08, 10), P.mat("3a3a3a"), Vector3(0, 0.58, 0))
	return g

static func mooring() -> Node3D:
	var g := Node3D.new()
	for s in [-1.4, 1.4]: Props._add(g, P.cyl(0.14, 0.16, 2.6, 8), P.wood("6a5440"), Vector3(s, -0.6, 0.6))
	Props._add(g, P.box(3.4, 0.12, 1.2), P.wood("8a6a4a"), Vector3(0, 0.02, 0.6))
	return g

static func rubble(seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stone := P.stone("8a8a86")
	for k in 6:
		var s := rng.randf_range(0.4, 1.1)
		Props._add(g, P.box(s, s * 0.7, s * 0.9), stone, Vector3(rng.randf_range(-1.6, 1.6), s * 0.3, rng.randf_range(-1.6, 1.6)), Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4))
	return g

static func payphone() -> Node3D:
	var g := Node3D.new()
	Props._add(g, P.box(0.12, 2.1, 0.12), P.mat("8a8a86"), Vector3(0, 1.05, -0.2))
	Props._add(g, P.box(0.55, 0.7, 0.32), P.mat("c84a2c"), Vector3(0, 1.4, 0))
	Props._add(g, P.box(0.7, 0.08, 0.5), P.mat("8a8a86"), Vector3(0, 1.9, -0.05))
	Props._add(g, P.box(0.12, 0.3, 0.08), P.mat("222222"), Vector3(-0.15, 1.45, 0.19))
	return g

static func cannon() -> Node3D:
	var g := Node3D.new()
	Props._add(g, P.box(0.8, 0.4, 1.2), P.wood("5e4632"), Vector3(0, 0.3, 0))
	Props._add(g, P.cyl(0.16, 0.22, 2.0, 10), P.mat("2f3330"), Vector3(0, 0.7, 0.3), Vector3(PI / 2.0 - 0.15, 0, 0))
	return g

static func nonna_balcony(w: float, drop: float) -> Node3D:
	var g := Node3D.new()
	var iron := P.mat("2f3330")
	Props._add(g, P.box(w, 0.15, 1.0), P.stone("cfc8bd"), Vector3(0, 0, 0.5))
	Props._add(g, P.box(w, 0.05, 0.05), iron, Vector3(0, 0.95, 0.98))
	for k in int(w / 0.15): Props._add(g, P.box(0.02, 0.9, 0.02), iron, Vector3(-w / 2.0 + 0.1 + k * 0.15, 0.5, 0.98))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 14:
		var x := -w / 2.0 + 0.25 + rng.randf() * (w - 0.5)
		var z := 0.2 + rng.randf() * 0.6
		var s := rng.randf_range(0.7, 1.3)
		Props._add(g, Palazzo.pot_mesh(), P.mat("b5653a"), Vector3(x, 0.15 + 0.12 * s, z), Vector3.ZERO, Vector3(0.3, 0.24, 0.3) * s)
		Props._add(g, Palazzo.leaf_mesh(), P.mat("4f8a3a"), Vector3(x, 0.45 + 0.2 * s, z), Vector3.ZERO, Vector3(0.42, 0.36, 0.42) * s)
	var basket := Node3D.new()
	basket.name = "nonna_basket"
	basket.position = Vector3(w / 2.0 - 0.3, -drop + 1.1, 1.2)
	g.add_child(basket)
	Props._add(basket, P.cyl(0.25, 0.2, 0.3, 10), P.wood("c8a060"), Vector3(0, 0.15, 0))
	Props._add(g, P.cyl(0.01, 0.01, drop - 0.8, 4), P.mat("d8d0c0"), Vector3(w / 2.0 - 0.3, -drop / 2.0 + 0.95, 1.2), Vector3.ZERO, Vector3.ONE, false)
	return g

static func fish_boxes() -> Node3D:
	var g := Node3D.new()
	var wood := P.wood("c8a878")
	for k in 4:
		Props._add(g, P.box(0.6, 0.2, 0.4), wood, Vector3((k % 2) * 0.65, 0.1 + floorf(k / 2.0) * 0.21, 0))
	return g

static func capers(seed: int) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var leaf := P.mat("5f8a4a")
	var bloom := P.mat("f2e6ea")
	for k in 5:
		var p := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 1.4), rng.randf_range(0.0, 0.15))
		Props._add(g, Palazzo.leaf_mesh(), leaf, p, Vector3.ZERO, Vector3(0.45, 0.32, 0.25))
		if rng.randf() < 0.6: Props._add(g, P.sphere(0.05, 6, 4), bloom, p + Vector3(0.1, 0.12, 0.12))
	return g

static func flagmast() -> Node3D:
	var g := Node3D.new()
	Props._add(g, P.cyl(0.05, 0.08, 6.0, 8), P.mat("e8e4dc"), Vector3(0, 3.0, 0))
	var cols := ["2f8a4a", "f2efe6", "c8302c"]
	for i in 3: Props._add(g, P.box(0.45, 0.9, 0.03), P.fabric(cols[i]), Vector3(0.3 + i * 0.45, 5.4, 0))
	return g
