extends RefCounted

const P := preload("res://scripts/world/palette.gd")
const SLATE := Color("7e8189")
const DARK := "17171c"
const FRAME := "efeae0"
const STONE_TRIM := "cfc6b4"

static func seeded(b: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%s" % [b.get("id", ""), b.x, b.z])
	return rng

static func make(b: Dictionary) -> Node3D:
	match String(b.kind):
		"cliffs_church": return church(b)
		"cliffs_church_tower": return tower(b)
		"cliffs_cellar": return cellar(b)
		"cliffs_workshop": return workshop(b)
		"cliffs_sanctuary": return sanctuary(b)
		"cliffs_hut": return hut(b)
		"cliffs_arch": return arch(b)
		"cliffs_tunnel_w", "cliffs_tunnel_e": return tunnel(b)
		"cliffs_track_w", "cliffs_track_e": return track(b)
	var g := Node3D.new()
	var h := float(b.get("h", 3.0))
	Props._add(g, P.box(float(b.w), h, float(b.d)), P.plaster(String(b.get("wall", "#e8dcc4"))), Vector3(0, h / 2.0, 0))
	return g

static func kit_house(b: Dictionary) -> Node3D:
	var o := HouseKit.build(b)
	frames(o, Interiors.enterable(b))
	return o

static func frames(o: Node3D, ground_only: bool) -> void:
	var win := HouseKit.part_mesh("window")
	var bb := win.get_aabb()
	var mat := P.plaster(FRAME)
	var band := 0.15
	var x0 := bb.position.x; var x1 := bb.end.x; var y0 := bb.position.y; var y1 := bb.end.y
	var z := bb.end.z + 0.004
	var bars: Array = [
		Transform3D(Basis.from_scale(Vector3(band, y1 - y0 + band * 2.0, 0.02)), Vector3(x0 - band / 2.0, (y0 + y1) / 2.0, z)),
		Transform3D(Basis.from_scale(Vector3(band, y1 - y0 + band * 2.0, 0.02)), Vector3(x1 + band / 2.0, (y0 + y1) / 2.0, z)),
		Transform3D(Basis.from_scale(Vector3(x1 - x0 + band * 2.0, band * 1.3, 0.02)), Vector3((x0 + x1) / 2.0, y1 + band * 0.65, z)),
		Transform3D(Basis.from_scale(Vector3(x1 - x0 + band * 2.0, band, 0.02)), Vector3((x0 + x1) / 2.0, y0 - band / 2.0, z)),
	]
	for node in o.find_children("*", "MultiMeshInstance3D", true, false):
		var m := node as MultiMeshInstance3D
		if m.multimesh == null or m.multimesh.mesh != win: continue
		var keep: Array = []
		for i in m.multimesh.instance_count:
			var xf := m.multimesh.get_instance_transform(i)
			if ground_only and xf.origin.y > 2.4: continue
			keep.append(xf)
		if keep.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = HouseKit.unit_box()
		mm.instance_count = keep.size() * bars.size()
		var n := 0
		for xf in keep:
			for bar in bars:
				mm.set_instance_transform(n, xf * bar)
				n += 1
		var f := MultiMeshInstance3D.new()
		f.name = "painted_frames"
		f.multimesh = mm
		f.material_override = mat
		f.transform = m.transform
		m.get_parent().add_child(f)

static func slate_roof(parent: Node3D, b: Dictionary, h: float, wall: Material) -> Node3D:
	var along_z: bool = float(b.d) > float(b.w)
	var length: float = float(b.d) if along_z else float(b.w)
	var span: float = float(b.w) if along_z else float(b.d)
	var node := Node3D.new()
	node.name = "roof"
	if along_z: node.rotation.y = PI / 2.0
	parent.add_child(node)
	var parts := HouseKit.Parts.new(node)
	parts.slate = true
	var rise := parts.roof(length, span, h, Color(String(b.get("roof", "#7e8189"))), seeded(b), HouseKit.SIDE_OVERHANG, HouseKit.SIDE_OVERHANG, 0.0, false)
	var infill := PrismMesh.new()
	infill.size = Vector3(span, rise, length)
	infill.left_to_right = 0.5
	Props._add(node, infill, wall, Vector3(0, h + rise / 2.0 - 0.01, 0), Vector3(0, PI / 2.0, 0))
	parts.flush()
	node.set_meta("rise", rise)
	return node

static func shell(b: Dictionary, mat: Material, h: float) -> Dictionary:
	var g := Node3D.new()
	var low := Node3D.new()
	low.name = "walls"
	g.add_child(low)
	var high := Node3D.new()
	high.name = "upper"
	g.add_child(high)
	var split := minf(h, 2.6)
	for r in Interiors.walls(b):
		var w: float = r.maxX - r.minX
		var d: float = r.maxZ - r.minZ
		var c := Vector3((r.minX + r.maxX) / 2.0 - b.x, 0.0, (r.minZ + r.maxZ) / 2.0 - b.z)
		Props._add(low, P.box(w, split, d), mat, c + Vector3(0, split / 2.0, 0))
		if h > split: Props._add(high, P.box(w, h - split, d), mat, c + Vector3(0, split + (h - split) / 2.0, 0))
	var di := Interiors.door_info(b)
	var dc: Vector2 = di.c - Vector2(b.x, b.z)
	var across: bool = absf(di.along.x) > 0.5
	var lw: float = Interiors.DOOR_W if across else Interiors.WALL_T
	var ld: float = Interiors.WALL_T if across else Interiors.DOOR_W
	var mid: Vector2 = dc - di.out * Interiors.WALL_T / 2.0
	var trim := P.stone(STONE_TRIM)
	if split > Interiors.DOOR_H + 0.2:
		Props._add(low, P.box(lw, split - Interiors.DOOR_H, ld), mat, Vector3(mid.x, Interiors.DOOR_H + (split - Interiors.DOOR_H) / 2.0, mid.y))
		var outer: Vector2 = dc + di.out * 0.04
		for s in [-1.0, 1.0]:
			var p: Vector2 = outer + di.along * s * (Interiors.DOOR_W / 2.0 + 0.09)
			Props._add(low, P.box(0.18 if across else 0.1, Interiors.DOOR_H + 0.16, 0.1 if across else 0.18), trim, Vector3(p.x, (Interiors.DOOR_H + 0.16) / 2.0, p.y))
		Props._add(low, P.box(Interiors.DOOR_W + 0.36 if across else 0.12, 0.2, 0.12 if across else Interiors.DOOR_W + 0.36), trim, Vector3(outer.x, Interiors.DOOR_H + 0.12, outer.y))
	if h > split: Props._add(high, P.box(lw, h - split, ld), mat, Vector3(mid.x, split + (h - split) / 2.0, mid.y))
	for s in [-1.0, 1.0]:
		var hw: float = float(b.w) / 2.0 + 0.06
		var hd: float = float(b.d) / 2.0 + 0.06
		Props._add(low, P.box(float(b.w) + 0.12, 0.32, 0.12), trim, Vector3(0, 0.16, s * hd))
		Props._add(low, P.box(0.12, 0.32, float(b.d) + 0.12), trim, Vector3(s * hw, 0.16, 0))
	return {"g": g, "low": low, "high": high, "door": dc, "out": di.out, "along": di.along}

static func finish(sh: Dictionary, roof: Node3D) -> Node3D:
	var g: Node3D = sh.g
	var fade: Array = [sh.high]
	if roof != null: fade.append(roof)
	g.set_meta("fade_parts", Props.fade_parts(fade))
	return g

static func arched_window(parent: Node3D, pos: Vector3, rot_y: float, w: float, h: float) -> void:
	var dark := P.mat(DARK)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	Props._add(n, P.box(w, h - w / 2.0, 0.06), dark, Vector3(0, (h - w / 2.0) / 2.0, 0.0))
	Props._add(n, P.cyl(w / 2.0, w / 2.0, 0.06, 14), dark, Vector3(0, h - w / 2.0, 0.0), Vector3(PI / 2.0, 0, 0))
	Props._add(n, P.box(w + 0.16, 0.08, 0.1), P.stone(STONE_TRIM), Vector3(0, -0.04, 0.02))

static func church(b: Dictionary) -> Node3D:
	var h := float(b.h)
	var mat := P.stone(String(b.wall))
	var sh := shell(b, mat, h)
	var roof := slate_roof(sh.g, b, h, mat)
	var hw: float = float(b.w) / 2.0 + 0.03
	var hd: float = float(b.d) / 2.0 + 0.03
	for z in [-2.6, 0.6, 3.6]:
		arched_window(sh.high, Vector3(hw, 3.2, z), PI / 2.0, 0.7, 1.9)
		arched_window(sh.high, Vector3(-hw, 3.2, z + 0.4), -PI / 2.0, 0.7, 1.9)
	var rise: float = roof.get_meta("rise")
	var rose := Node3D.new()
	rose.position = Vector3(0, h + rise * 0.4, hd)
	sh.high.add_child(rose)
	Props._add(rose, P.torus(0.62, 0.11, 20), P.stone(STONE_TRIM), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	Props._add(rose, P.cyl(0.58, 0.58, 0.04, 20), P.mat(DARK), Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	return finish(sh, roof)

static func tower(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var mat := P.stone(String(b.wall))
	var w := float(b.w)
	var top := float(b.h) - 2.6
	Props._add(g, P.box(w, top, w), mat, Vector3(0, top / 2.0, 0))
	var dark := P.mat(DARK)
	for k in 4:
		var a := k * PI / 2.0
		var out := Vector3(sin(a), 0, cos(a)) * (w / 2.0 + 0.02)
		var n := Node3D.new()
		n.position = out + Vector3(0, top - 2.4, 0)
		n.rotation.y = a
		g.add_child(n)
		Props._add(n, P.box(0.9, 1.4, 0.06), dark, Vector3(0, 0.7, 0))
		Props._add(n, P.cyl(0.45, 0.45, 0.06, 12), dark, Vector3(0, 1.4, 0), Vector3(PI / 2.0, 0, 0))
	Props._add(g, P.box(w + 0.3, 0.22, w + 0.3), P.stone(STONE_TRIM), Vector3(0, top + 0.11, 0))
	Props._add(g, P.box(w + 0.24, 0.18, w + 0.24), P.stone(STONE_TRIM), Vector3(0, top - 2.9, 0))
	Props._add(g, P.cyl(0.42, 0.55, 0.7, 14), P.mat("8a6a3a"), Vector3(0, top - 1.3, 0))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.0
	spire.bottom_radius = w * 0.78
	spire.height = 2.6
	spire.radial_segments = 4
	spire.rings = 1
	Props._add(g, spire, HouseKit.tile_material(SLATE), Vector3(0, top + 0.22 + 1.3, 0), Vector3(0, PI / 4.0, 0))
	Props._add(g, P.box(0.06, 0.7, 0.06), P.mat("3a3a40"), Vector3(0, top + 0.22 + 2.6 + 0.3, 0))
	Props._add(g, P.box(0.36, 0.06, 0.06), P.mat("3a3a40"), Vector3(0, top + 0.22 + 2.6 + 0.42, 0))
	return g

static func cellar(b: Dictionary) -> Node3D:
	var h := float(b.h)
	var mat := P.stone(String(b.wall))
	var sh := shell(b, mat, h)
	var roof := slate_roof(sh.g, b, h, mat)
	var hd: float = float(b.d) / 2.0 + 0.03
	for x in [-3.0, 3.0]:
		var n := Node3D.new()
		n.position = Vector3(x, 1.5, hd)
		sh.low.add_child(n)
		Props._add(n, P.box(0.7, 0.55, 0.06), P.mat(DARK), Vector3.ZERO)
		for k in 4: Props._add(n, P.box(0.03, 0.55, 0.05), P.mat("3a3a40"), Vector3(-0.27 + k * 0.18, 0, 0.03))
	return finish(sh, roof)

static func workshop(b: Dictionary) -> Node3D:
	var h := float(b.h)
	var mat := P.plaster(String(b.wall))
	var sh := shell(b, mat, h)
	var roof := slate_roof(sh.g, b, h, mat)
	var hd: float = float(b.d) / 2.0 + 0.03
	var n := Node3D.new()
	n.position = Vector3(1.8, 1.4, hd)
	sh.low.add_child(n)
	Props._add(n, P.box(1.0, 0.8, 0.06), P.mat(DARK), Vector3.ZERO)
	Props._add(n, P.box(1.12, 0.06, 0.12), P.stone(STONE_TRIM), Vector3(0, -0.42, 0.03))
	return finish(sh, roof)

static func sanctuary(b: Dictionary) -> Node3D:
	var h := float(b.h)
	var mat := P.plaster(String(b.wall))
	var sh := shell(b, mat, h)
	var roof := slate_roof(sh.g, b, h, mat)
	var rise: float = roof.get_meta("rise")
	var gable := Node3D.new()
	gable.name = "bell_gable"
	gable.position = Vector3(float(b.w) / 2.0 - 0.15, h + rise - 0.2, 0)
	sh.high.add_child(gable)
	Props._add(gable, P.box(0.3, 1.7, 1.5), mat, Vector3(0, 0.85, 0))
	Props._add(gable, P.box(0.34, 0.9, 0.7), P.mat(DARK), Vector3(0, 0.75, 0))
	Props._add(gable, P.cyl(0.24, 0.32, 0.42, 12), P.mat("8a6a3a"), Vector3(0, 0.62, 0))
	Props._add(gable, P.box(0.06, 0.5, 0.06), P.mat("3a3a40"), Vector3(0, 1.95, 0))
	Props._add(gable, P.box(0.06, 0.06, 0.3), P.mat("3a3a40"), Vector3(0, 2.05, 0))
	var hd: float = float(b.d) / 2.0 + 0.03
	arched_window(sh.low, Vector3(0.4, 0.9, hd), 0.0, 0.5, 1.3)
	arched_window(sh.low, Vector3(0.4, 0.9, -hd), PI, 0.5, 1.3)
	return finish(sh, roof)

static func hut(b: Dictionary) -> Node3D:
	var mat := P.stone(String(b.wall))
	var sh := shell(b, mat, 1.8)
	var rng := seeded(b)
	var stones := HouseKit.Parts.new(sh.low)
	for r in Interiors.walls(b):
		var w: float = r.maxX - r.minX
		var d: float = r.maxZ - r.minZ
		var along_x := w >= d
		var length := w if along_x else d
		var n := int(length / 0.4)
		for k in n:
			if rng.randf() < 0.35: continue
			var u := -length / 2.0 + (k + 0.5) * length / n
			var c := Vector3((r.minX + r.maxX) / 2.0 - b.x, 0.0, (r.minZ + r.maxZ) / 2.0 - b.z)
			var p := c + (Vector3(u, 0, 0) if along_x else Vector3(0, 0, u))
			var hh := rng.randf_range(0.12, 0.4)
			var t := rng.randf_range(0.85, 1.05)
			stones.put(HouseKit.unit_box(), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)) * Basis.from_scale(Vector3(0.36, hh, 0.3)), p + Vector3(0, 1.8 + hh / 2.0, 0)), false, HouseKit.tinted(P.stone(String(b.wall))), Color(t, t, t))
	stones.flush()
	sh.g.set_meta("fade_parts", [])
	return sh.g

static func arch(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var mat := P.stone(String(b.wall))
	var w := float(b.w)
	var d := float(b.d)
	var h := float(b.h)
	Props._add(g, P.box(w + 2.4, h, d), mat, Vector3(0, h / 2.0, 0))
	for s in [-1.0, 1.0]:
		Props._add(g, P.box(w + 2.4, 0.55, 0.22), mat, Vector3(0, h + 0.27, s * (d / 2.0 - 0.11)))
	var R := 3.3
	var trim := P.stone(STONE_TRIM)
	var n := 11
	for k in n:
		var a := PI * (k + 0.5) / n
		var p := Vector3(R * cos(a), -R + R * sin(a) + 0.1, 0)
		Props._add(g, P.box(0.5, R * PI / n + 0.04, d + 0.06), trim, p, Vector3(0, 0, a - PI / 2.0))
	for s in [-1.0, 1.0]:
		Props._add(g, P.box(1.4, 1.8, d), mat, Vector3(s * (w / 2.0 + 0.5), -0.9, 0))
	return g

static func tunnel(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var face := 1.0 if String(b.kind) == "cliffs_tunnel_w" else -1.0
	var mat := P.stone(String(b.wall))
	var w := float(b.w)
	var d := float(b.d)
	var h := float(b.h)
	var fx := face * (w / 2.0 - 0.35)
	Props._add(g, P.box(0.7, h, d), mat, Vector3(fx, h / 2.0, 0))
	Props._add(g, P.box(0.74, 3.4, 3.6), P.mat(DARK), Vector3(fx + face * 0.02, 1.7, 0))
	Props._add(g, P.cyl(1.8, 1.8, 0.74, 18), P.mat(DARK), Vector3(fx + face * 0.02, 3.4, 0), Vector3(0, 0, PI / 2.0))
	Props._add(g, P.torus(1.95, 0.16, 20), P.stone(STONE_TRIM), Vector3(fx + face * 0.38, 3.4, 0), Vector3(0, 0, PI / 2.0))
	Props._add(g, P.box(0.9, 0.3, d + 0.3), P.stone(STONE_TRIM), Vector3(fx, h - 0.15, 0))
	return g

static func track(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var w := float(b.w)
	var d := float(b.d)
	Props._add(g, P.box(w, 0.3, d - 0.4), P.stone("8d877e"), Vector3(0, 0.15, 0))
	var parts := HouseKit.Parts.new(g)
	var sleeper := HouseKit.tinted(P.wood("5b4636"))
	var n := int(w / 0.65)
	for k in n:
		var x := -w / 2.0 + (k + 0.5) * w / n
		parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(0.24, 0.1, 2.4)), Vector3(x, 0.34, 0)), false, sleeper, Color.WHITE)
	parts.flush()
	for z in [-0.72, 0.72]:
		Props._add(g, P.box(w, 0.13, 0.08), P.mat("6e6a66"), Vector3(0, 0.45, z))
	return g
