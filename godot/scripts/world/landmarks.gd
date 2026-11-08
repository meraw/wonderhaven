class_name Landmarks
extends RefCounted

const P := preload("res://scripts/world/palette.gd")
const STONE := "d9cdb4"
const TRIM := "efe4cc"
const HALL_LIGHT := Color("ffc98a")

static func seeded(b: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%s" % [b.get("id", ""), b.x, b.z])
	return rng

static func facade(w: float, d: float, side: String) -> Transform3D:
	match side:
		"N": return Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -d / 2.0))
		"E": return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(w / 2.0, 0, 0))
		"W": return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-w / 2.0, 0, 0))
	return Transform3D(Basis.IDENTITY, Vector3(0, 0, d / 2.0))

static func glass_material() -> StandardMaterial3D:
	var m := P.unique_mat(HouseKit.GLASS, "ffcf6b", 0.0)
	if P.real:
		m.roughness = 0.12
		m.metallic_specular = 0.6
	return m

static func shutter_state(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	return "open" if r < 0.6 else ("shut" if r < 0.75 else ("ajar" if r < 0.9 else "half"))

static func corner_quoins(parts: HouseKit.Parts, w: float, d: float, top: float, col: String, rng: RandomNumberGenerator) -> void:
	var mat := HouseKit.tinted(P.stone(Color(col)))
	var y := 0.78
	var k := 0
	while y < top - 0.3:
		var lf := Vector2(0.56, 0.3) if k % 2 == 0 else Vector2(0.3, 0.56)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var t := rng.randf_range(0.92, 1.05)
				parts.put(HouseKit.unit_box(), Transform3D(Basis.from_scale(Vector3(lf.x, 0.34, lf.y)), Vector3(sx * (w / 2.0 - lf.x / 2.0 + 0.04), y + 0.17, sz * (d / 2.0 - lf.y / 2.0 + 0.04))), false, mat, Color(t, t, t * 0.98))
		y += 0.37
		k += 1

static func kit_roof(parent: Node3D, length: float, span: float, h: float, along_z: bool, color: Color, wall: Material, rng: RandomNumberGenerator, overhang: float = HouseKit.SIDE_OVERHANG) -> Node3D:
	var node := Node3D.new()
	node.name = "roof"
	if along_z: node.rotation.y = PI / 2.0
	parent.add_child(node)
	var parts := HouseKit.Parts.new(node)
	var rise := parts.roof(length, span, h, color, rng, overhang, overhang, 0.03, false)
	var infill := PrismMesh.new()
	infill.size = Vector3(span, rise, length)
	infill.left_to_right = 0.5
	Props._add(node, infill, wall, Vector3(0, h + rise / 2.0 - 0.01, 0), Vector3(0, PI / 2.0, 0))
	parts.flush()
	node.set_meta("rise", rise)
	return node

static func workshop(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var h := 2.6
	var t := 0.35
	var hw: float = b.w / 2.0
	var hd: float = b.d / 2.0
	var rng := seeded(b)
	var wall_mat := P.plaster(b.wall)
	var g0: float = b.doorAt - b.z - b.doorWidth / 2.0
	var g1: float = b.doorAt - b.z + b.doorWidth / 2.0
	var walls := Node3D.new()
	walls.name = "walls"
	g.add_child(walls)
	var addw := func(w: float, d: float, x: float, z: float): Props._add(walls, P.box(w, h, d), wall_mat, Vector3(x, h / 2.0, z))
	addw.call(b.w, t, 0.0, -hd + t / 2.0)
	addw.call(b.w, t, 0.0, hd - t / 2.0)
	addw.call(t, b.d, -hw + t / 2.0, 0.0)
	addw.call(t, g0 + hd, hw - t / 2.0, (-hd + g0) / 2.0)
	addw.call(t, hd - g1, hw - t / 2.0, (g1 + hd) / 2.0)
	Props._add(walls, P.box(t, h - 1.9, g1 - g0), wall_mat, Vector3(hw - t / 2.0, 1.9 + (h - 1.9) / 2.0, (g0 + g1) / 2.0))
	var stone := P.stone("cdc3ae")
	for z in [g0 - 0.1, g1 + 0.1]: Props._add(g, P.box(0.14, 1.95, 0.2), stone, Vector3(hw + 0.04, 0.975, z))
	Props._add(g, P.box(0.16, 0.24, g1 - g0 + 0.44), stone, Vector3(hw + 0.05, 2.02, (g0 + g1) / 2.0))
	Props._add(g, P.box(b.w - 0.2, 0.06, b.d - 0.2), P.wood("d9b48a"), Vector3(0, 0.03, 0))
	var x := -hw + 0.6
	while x < hw:
		Props._add(g, P.box(0.03, 0.065, b.d - 0.3), P.wood("c49a6c"), Vector3(x, 0.035, 0), Vector3.ZERO, Vector3.ONE, false)
		x += 0.9
	var along_z: bool = b.d > b.w
	var roof := kit_roof(g, maxf(b.w, b.d), minf(b.w, b.d), h, along_z, Color(b.roof), wall_mat, rng)
	g.set_meta("fade_parts", Props.fade_parts([roof]))
	var trim := P.plaster(TRIM)
	for zs in [-1, 1]: Props._add(g, P.box(b.w + 0.06, 0.16, t + 0.06), trim, Vector3(0, h - 0.08, zs * (hd - t / 2.0)))
	for xs in [-1, 1]: Props._add(g, P.box(t + 0.06, 0.16, b.d + 0.06), trim, Vector3(xs * (hw - t / 2.0), h - 0.08, 0))
	Props._add(g, P.rbox(1.6, 0.5, 0.1, 0.05), P.wood("8b5a3c"), Vector3(hw + 0.1, 2.25, b.doorAt - b.z - 1.6), Vector3(0, PI / 2, 0))
	var gear := Props._add(g, P.torus(0.22, 0.07, 10), P.mat(P.GOLD), Vector3(hw + 0.17, 2.25, b.doorAt - b.z - 1.6), Vector3(0, 0, PI / 2))
	gear.name = "signGear"
	var parts := HouseKit.Parts.new(g)
	parts.glass_mat = glass_material()
	var hs: Dictionary = Data.layout.get("houseStyle", {})
	var shutter := String(hs.get("shutters", HouseKit.SHUTTER_KEY)).trim_prefix("#")
	for side in ["S", "N"]:
		for u in [-1.8, 1.8]: parts.window(facade(b.w, b.d, side) * Transform3D(Basis.IDENTITY, Vector3(u, 0.85, 0.0)), 1.0, 1.3, shutter, shutter_state(rng))
	var footing := HouseKit.tinted(P.stone(HouseKit.FOOTING_STONE))
	parts.stones(b.w, HouseKit.FOOTING, facade(b.w, b.d, "S"), footing, rng)
	parts.stones(b.w, HouseKit.FOOTING, facade(b.w, b.d, "N"), footing, rng)
	parts.stones(b.d, HouseKit.FOOTING, facade(b.w, b.d, "W"), footing, rng)
	parts.stones(b.d, HouseKit.FOOTING, facade(b.w, b.d, "E"), footing, rng, -g1 - 0.2, -g0 + 0.2)
	if hs.has("quoins"): corner_quoins(parts, b.w, b.d, h, String(hs.quoins), rng)
	parts.flush()
	g.set_meta("glasses", parts.glasses)
	var clutter := Node3D.new()
	clutter.name = "clutter"
	g.add_child(clutter)
	for c in [[-3.3, -2.4, 0.6], [-3.6, 2.4, 0.5], [2.6, 2.6, 0.55]]: Props._add(clutter, P.rbox(c[2], c[2], c[2], 0.04), P.mat("a88a6a"), Vector3(c[0], c[2] / 2.0, c[1]), Vector3(0, c[0], 0))
	for c in [[-hw + 0.4, -hd + 0.4, 0.8], [-hw + 0.4, hd - 0.4, -0.8]]: Props._add(clutter, P.box(0.8, 0.6, 0.01), P.glow_mat(Color("e8e8e8"), 0.5), Vector3(c[0], 2.3, c[1]), Vector3(0, c[2], 0), Vector3.ONE, false)
	return g

static func church(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var rng := seeded(b)
	var tower_w := 2.4
	var nave_w: float = b.w - tower_w
	var h := 4.6
	var wall := P.plaster(b.get("wall", "#ead2a0"))
	var roof_col := Color(b.get("roof", "#c4623a"))
	var nave := Node3D.new()
	nave.position.x = -tower_w / 2.0
	g.add_child(nave)
	Props._add(nave, P.box(nave_w, h, b.d), wall, Vector3(0, h / 2.0, 0))
	var front: String = "N" if b.door == "N" else "S"
	var back: String = "S" if front == "N" else "N"
	var sgn := -1.0 if front == "N" else 1.0
	var roof := kit_roof(nave, b.d, nave_w, h, true, roof_col, wall, rng, 0.35)
	var rise: float = roof.get_meta("rise")
	var parts := HouseKit.Parts.new(nave)
	var glass := glass_material()
	parts.glass_mat = glass
	var footing := HouseKit.tinted(P.stone(HouseKit.FOOTING_STONE))
	parts.stones(nave_w, HouseKit.FOOTING, facade(nave_w, b.d, front), footing, rng, -1.0, 1.0)
	parts.stones(nave_w, HouseKit.FOOTING, facade(nave_w, b.d, back), footing, rng)
	parts.stones(b.d, HouseKit.FOOTING, facade(nave_w, b.d, "W"), footing, rng)
	parts.stones(b.d, HouseKit.FOOTING, facade(nave_w, b.d, "E"), footing, rng)
	corner_quoins(parts, nave_w, b.d, h, STONE, rng)
	var fx := facade(nave_w, b.d, front)
	parts.put(HouseKit.part_mesh("door_arched", {"6e4428": "6b3a22"}), fx * Transform3D(Basis.from_scale(Vector3.ONE * 1.2), Vector3.ZERO))
	parts.put(HouseKit.part_mesh("door_arched", {}, true), fx * Transform3D(Basis.from_scale(Vector3.ONE * 1.2), Vector3.ZERO), false, glass, Color.WHITE, false)
	var face := Node3D.new()
	face.transform = fx
	nave.add_child(face)
	var steps := P.stone("d8d0c2")
	Props._add(face, P.rbox(2.6, 0.18, 1.2, 0.05), steps, Vector3(0, 0.09, 0.75))
	Props._add(face, P.rbox(2.1, 0.18, 0.8, 0.05), steps, Vector3(0, 0.27, 0.5))
	Props._add(face, P.torus(0.55, 0.08, 24), P.stone(STONE), Vector3(0, 3.55, 0.04), Vector3(PI / 2, 0, 0))
	var rose := Props._add(face, P.cyl(0.5, 0.5, 0.04, 24), P.unique_mat("8a6fb8", "ffcf6b", 0.0), Vector3(0, 3.55, 0.02), Vector3(PI / 2, 0, 0))
	rose.name = "glass"
	var rake := sqrt(pow(nave_w / 2.0 + 0.35, 2.0) + rise * rise)
	var ang := atan2(rise, nave_w / 2.0 + 0.35)
	for s in [-1.0, 1.0]: Props._add(face, P.box(rake, 0.16, 0.18), P.stone(STONE), Vector3(s * (nave_w / 4.0 + 0.17), h + rise / 2.0 + 0.04, 0.06), Vector3(0, 0, -s * ang))
	Props._add(face, P.box(nave_w + 0.3, 0.2, 0.16), P.stone(STONE), Vector3(0, h + 0.02, 0.06))
	Props._add(face, P.box(0.1, 0.6, 0.08), P.stone(STONE), Vector3(0, h + rise + 0.45, 0.0))
	Props._add(face, P.box(0.36, 0.1, 0.08), P.stone(STONE), Vector3(0, h + rise + 0.55, 0.0))
	for side in ["W", "E"]:
		for zz in [-b.d * 0.22, b.d * 0.22]:
			if side == "E" and zz * sgn < 0.0: continue
			var u: float = zz if side == "W" else -zz
			parts.window(facade(nave_w, b.d, side) * Transform3D(Basis.IDENTITY, Vector3(u, 1.7, 0.0)), 0.7, 1.9)
	parts.flush()
	var glasses: Array = [rose]
	glasses.append_array(parts.glasses)
	g.set_meta("glasses", glasses)
	var brick := P.stone("b8673f")
	var tw := Node3D.new()
	tw.position = Vector3(b.w / 2.0 - tower_w / 2.0, 0, -sgn * (b.d / 2.0 - tower_w / 2.0))
	g.add_child(tw)
	var th := 8.4
	Props._add(tw, P.box(tower_w, th, tower_w), brick, Vector3(0, th / 2.0, 0))
	var tparts := HouseKit.Parts.new(tw)
	corner_quoins(tparts, tower_w, tower_w, th, STONE, rng)
	tparts.stones(tower_w, HouseKit.FOOTING, facade(tower_w, tower_w, "E"), footing, rng)
	tparts.stones(tower_w, HouseKit.FOOTING, facade(tower_w, tower_w, back), footing, rng)
	tparts.flush()
	for y in [3.0, 6.0]: Props._add(tw, P.box(tower_w + 0.16, 0.16, tower_w + 0.16), P.stone(STONE), Vector3(0, y, 0))
	var clock := Node3D.new()
	clock.position = Vector3(0, 6.9, sgn * (tower_w / 2.0 + 0.02))
	clock.rotation.y = 0.0 if sgn > 0 else PI
	tw.add_child(clock)
	Props._add(clock, P.cyl(0.62, 0.62, 0.06, 28), P.mat("f4f1ea"), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	Props._add(clock, P.torus(0.62, 0.05, 28), P.mat("3a2c22"), Vector3(0, 0, 0.02), Vector3(PI / 2, 0, 0))
	var hh := Props._add(clock, P.box(0.05, 0.38, 0.03), P.mat("2a2a2a"), Vector3(0, 0.15, 0.05))
	hh.rotation.z = -0.6
	Props._add(clock, P.box(0.04, 0.5, 0.03), P.mat("2a2a2a"), Vector3(0.12, 0.2, 0.06), Vector3(0, 0, -0.45))
	var pier := P.stone(STONE)
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]: Props._add(tw, P.box(0.4, 2.0, 0.4), pier, Vector3(c[0] * (tower_w / 2.0 - 0.2), th + 1.0, c[1] * (tower_w / 2.0 - 0.2)))
	for s in ["N", "S", "E", "W"]:
		var sx := facade(tower_w, tower_w, s)
		var arch := Node3D.new()
		arch.transform = sx
		tw.add_child(arch)
		Props._add(arch, P.box(tower_w - 0.8, 0.22, 0.3), pier, Vector3(0, th + 1.86, -0.15))
		Props._add(arch, P.box(tower_w - 0.8, 0.5, 0.06), pier, Vector3(0, th + 0.25, -0.05))
	Props._add(tw, P.cyl(0.32, 0.45, 0.6, 14), P.mat("b8862e"), Vector3(0, th + 1.1, 0))
	Props._add(tw, P.box(tower_w + 0.3, 0.22, tower_w + 0.3), P.stone(STONE), Vector3(0, th + 2.05, 0))
	var pr := P.mi(P.cone(tower_w * 0.82, 1.7, 4), HouseKit.tile_material(roof_col), Vector3(0, th + 3.0, 0))
	pr.rotation.y = PI / 4
	tw.add_child(pr)
	Props._add(tw, P.sphere(0.14, 10, 8), P.mat(P.GOLD), Vector3(0, th + 3.95, 0))
	return g

static func castle(b: Dictionary) -> Node3D:
	var g := Node3D.new()
	var rng := seeded(b)
	var light := P.stone("eadfcd")
	var keep_mat := P.stone(b.wall)
	for r in Interiors.walls(b):
		var hh: float = r.h
		Props._add(g, P.box(r.maxX - r.minX, hh, r.maxZ - r.minZ), light if hh < 3.0 else keep_mat, Vector3((r.minX + r.maxX) / 2.0 - b.x, hh / 2.0, (r.minZ + r.maxZ) / 2.0 - b.z))
		if hh < 3.0:
			var horiz: bool = r.maxX - r.minX > r.maxZ - r.minZ
			var length: float = (r.maxX - r.minX) if horiz else (r.maxZ - r.minZ)
			var n := int(length / 0.9)
			for i in n:
				var tt := (i + 0.5) / n
				var cx: float = lerpf(r.minX, r.maxX, tt) if horiz else (r.minX + r.maxX) / 2.0
				var cz: float = (r.minZ + r.maxZ) / 2.0 if horiz else lerpf(r.minZ, r.maxZ, tt)
				Props._add(g, P.box(0.45, 0.45, 0.45), light, Vector3(cx - b.x, hh + 0.22, cz - b.z))
	var di := Interiors.door_info(b)
	for pair in [[b.w / 2.0, 0.5, 2.4], [b.w / 2.0 - 1.0, 0.35, 4.2]]:
		var c: Vector2 = Vector2(b.x, b.z) + di.out * (pair[0] - pair[1] / 2.0) - Vector2(b.x, b.z)
		var size := Vector3(Interiors.DOOR_W, pair[2] - Interiors.DOOR_H, pair[1]) if di.out.y != 0.0 else Vector3(pair[1], pair[2] - Interiors.DOOR_H, Interiors.DOOR_W)
		Props._add(g, P.box(size.x, size.y, size.z), light if pair[2] < 3.0 else keep_mat, Vector3(c.x, (pair[2] + Interiors.DOOR_H) / 2.0, c.y))
	Props._add(g, P.box(b.w + 0.1, 1.2, b.d + 0.1), P.stone("cfc6b6"), Vector3(0, Props.CASTLE_FLOOR - 0.01 - 0.6, 0), Vector3.ZERO, Vector3.ONE, false)
	Props._add(g, P.box(b.w - 2.4, 0.02, b.d - 2.4), P.paving("d8d0c2"), Vector3(0, Props.CASTLE_FLOOR - 0.01, 0), Vector3.ZERO, Vector3.ONE, false)
	var tiles := HouseKit.tile_material(Color(b.roof))
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var tx: float = c[0] * b.w / 2.0
		var tz: float = c[1] * b.d / 2.0
		Props._add(g, P.cyl(1.0, 1.1, 5.2, 14), P.stone(b.wall), Vector3(tx, 2.6, tz))
		Props._add(g, P.cyl(1.12, 1.12, 0.2, 14), P.stone(STONE), Vector3(tx, 5.1, tz))
		Props._add(g, P.cone(1.3, 2.2, 14), tiles, Vector3(tx, 6.3, tz))
		Props._add(g, P.cyl(0.03, 0.03, 0.9, 4), P.mat("666666"), Vector3(tx, 7.8, tz))
		for k in 3: Props._add(g, P.box(0.2, 0.36, 0.02), P.fabric(["2e8b57", "f4f1ea", "c8323c"][k]), Vector3(tx + 0.1 + k * 0.2, 8.05, tz))
	var kr := P.mi(P.cone((b.w - 2) * 0.62, 2.6, 4), HouseKit.tile_material(Color(b.roof)), Vector3.ZERO)
	kr.rotation.y = PI / 4
	var kh := Node3D.new()
	kh.position.y = 5.5
	kh.scale = Vector3(1, 1, (b.d - 2) / (b.w - 2))
	kh.add_child(kr)
	g.add_child(kh)
	var ceiling := Props._add(g, P.box(b.w - 2.0, 0.1, b.d - 2.0), P.stone("d8d0c2"), Vector3(0, 4.25, 0))
	g.set_meta("fade_parts", Props.fade_parts([kh, ceiling]))
	var gate_c: Vector2 = di.out * (b.w / 2.0 + 0.08)
	Props._add(g, P.box(0.02, 1.6, 0.9) if di.out.y == 0.0 else P.box(0.9, 1.6, 0.02), P.fabric("2f5f9e"), Vector3(gate_c.x, 3.4, gate_c.y))
	Props._add(g, P.sphere(0.25, 4, 2), P.mat(P.GOLD), Vector3(gate_c.x * 1.01, 3.5, gate_c.y * 1.01))
	var parts := HouseKit.Parts.new(g)
	parts.glass_mat = glass_material()
	var footing := HouseKit.tinted(P.stone(HouseKit.FOOTING_STONE))
	var door_side := String(b.get("door", "S"))
	for s in ["N", "S", "E", "W"]:
		var length: float = b.w if s in ["N", "S"] else b.d
		if s == door_side: parts.stones(length, 0.6, facade(b.w, b.d, s), footing, rng, -Interiors.DOOR_W / 2.0 - 0.2, Interiors.DOOR_W / 2.0 + 0.2)
		else: parts.stones(length, 0.6, facade(b.w, b.d, s), footing, rng)
	var kw: float = b.w - 2.0
	var kd: float = b.d - 2.0
	for s in ["N", "S", "E", "W"]:
		if s == door_side: continue
		var length: float = kw if s in ["N", "S"] else kd
		for u in [-length / 4.0, length / 4.0]: parts.window(facade(kw, kd, s) * Transform3D(Basis.IDENTITY, Vector3(u, 2.95, 0.0)), 0.75, 0.95, "", "open", true)
	var out := Vector3(di.out.x, 0.0, di.out.y)
	var inner: float = (kw if di.out.y == 0.0 else kd) / 2.0 - 0.35
	var along := Vector3(-out.z, 0.0, out.x)
	var lamp_basis := Basis(Vector3.UP, atan2(out.x, out.z))
	for s in [-1.6, 1.6]:
		var at: Vector3 = -out * inner + along * s
		parts.put(HouseKit.part_mesh("wall_lamp"), Transform3D(lamp_basis, at + Vector3(0, 2.5, 0)))
		parts.put(HouseKit.part_mesh("wall_lamp", {}, true), Transform3D(lamp_basis, at + Vector3(0, 2.5, 0)), false, parts.glass_mat, Color.WHITE, false)
		var lamp := OmniLight3D.new()
		lamp.light_color = HALL_LIGHT
		lamp.light_energy = 1.1
		lamp.omni_range = 4.6
		lamp.shadow_enabled = false
		lamp.position = at + out * 1.1 + Vector3(0, 2.3, 0)
		g.add_child(lamp)
	parts.flush()
	g.set_meta("glasses", parts.glasses)
	return g
