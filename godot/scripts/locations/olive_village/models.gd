extends RefCounted

const WHITEWASH := Color("f1ece0")
const STONE := Color("a39a8a")
const STONE_LIGHT := Color("c9bfae")
const TERRACOTTA := Color("b8643c")
const SHADOW := Color("2e3330")
const TILES := [Color("2f7d5b"), Color("e2b93b"), Color("f4f1ea"), Color("3f8f6b")]

static func build(b: Dictionary) -> Node3D:
	if b.get("kit", false): return null
	match String(b.get("kind", "")):
		"washhouse": return washhouse(b)
		"belltower": return belltower(b)
		"tower": return castle_tower(b)
		"tank": return tank(b)
	return null

static func two_sided(m: Material) -> Material:
	var c := m.duplicate() as BaseMaterial3D
	c.cull_mode = BaseMaterial3D.CULL_DISABLED
	return c

static func glaze() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.22
	m.metallic_specular = 0.85
	return m

static func gable(root: Node3D, w: float, d: float, eave: float, rise: float, over: float, mat: Material) -> void:
	var run := d / 2.0 + over
	var slope := sqrt(run * run + rise * rise)
	var a := atan2(rise, run)
	for side in [-1.0, 1.0]:
		var slab := Palette.mi(Palette.box(w + over * 2.0, 0.16, slope), mat, Vector3(0, eave + rise / 2.0, side * run / 2.0))
		slab.rotation.x = side * a
		root.add_child(slab)

static func washhouse(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	var w := float(b.w)
	var d := float(b.d)
	var stone := Palette.stone(STONE)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			root.add_child(Palette.mi(Palette.box(0.42, 2.6, 0.42), stone, Vector3(sx * (w / 2.0 - 0.21), 1.3, sz * (d / 2.0 - 0.21))))
	root.add_child(Palette.mi(Palette.box(w + 0.1, 0.3, d + 0.1), Palette.stone(STONE_LIGHT), Vector3(0, 2.6, 0)))
	gable(root, w, d, 2.72, 0.75, 0.3, HouseKit.tile_material(TERRACOTTA))
	root.add_child(Palette.mi(Palette.box(3.0, 0.75, 1.0), stone, Vector3(0, 0.37, 0)))
	root.add_child(Palette.mi(Palette.box(2.7, 0.05, 0.7), Palette.mat(Color("7f9ea3")), Vector3(0, 0.68, 0)))
	root.add_child(Palette.mi(Palette.box(0.4, 0.9, 1.2), stone, Vector3(-1.7, 0.45, 0)))
	root.add_child(Palette.mi(Palette.cyl(0.04, 0.04, 0.35, 6), Palette.mat(Color("8a8f8f")), Vector3(-1.45, 0.82, 0), true))
	return root

static func spire_mesh(base: float, height: float, rows: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := base / 2.0
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var apex := Vector3(0, height, 0)
	for f in 4:
		var a: Vector3 = corners[f]
		var b: Vector3 = corners[(f + 1) % 4]
		for r in rows:
			var t0 := float(r) / rows
			var t1 := float(r + 1) / rows
			var a0 := a.lerp(apex, t0)
			var b0 := b.lerp(apex, t0)
			var a1 := a.lerp(apex, t1)
			var b1 := b.lerp(apex, t1)
			var cols := rows - r
			for c in cols:
				var u0 := float(c) / cols
				var u1 := float(c + 1) / cols
				var p00 := a0.lerp(b0, u0)
				var p01 := a0.lerp(b0, u1)
				var top_cols := maxi(1, cols - 1)
				var q0 := a1.lerp(b1, clampf(float(c) / top_cols, 0.0, 1.0)) if cols > 1 else apex
				var q1 := a1.lerp(b1, clampf(float(c + 1) / top_cols, 0.0, 1.0)) if cols > 1 else apex
				var col: Color = TILES[(r + c + f) % TILES.size()]
				for v in [p00, q0, p01]:
					st.set_color(col)
					st.add_vertex(v)
				if c < cols - 1:
					var col2: Color = TILES[(r + c + f + 1) % TILES.size()]
					for v in [p01, q0, q1]:
						st.set_color(col2)
						st.add_vertex(v)
	st.generate_normals()
	return st.commit()

static func belltower(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	var w := float(b.w)
	var top := float(b.h) - 4.6
	var wall := Palette.plaster(Color(String(b.get("wall", WHITEWASH.to_html(false)))))
	var stone := Palette.stone(STONE)
	root.add_child(Palette.mi(Palette.box(w, top + 2.0, w), wall, Vector3(0, top / 2.0 - 1.0, 0)))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			root.add_child(Palette.mi(Palette.box(0.34, top + 2.0, 0.34), stone, Vector3(sx * (w / 2.0 - 0.15), top / 2.0 - 1.0, sz * (w / 2.0 - 0.15))))
	var dark := Palette.mat(SHADOW)
	for k in 4:
		var ang := k * PI / 2.0
		var out := Vector3(sin(ang), 0, cos(ang)) * (w / 2.0 + 0.01)
		var arch := Palette.mi(Palette.box(1.0, 1.7, 0.1), dark, out + Vector3(0, top - 1.4, 0))
		arch.rotation.y = ang
		root.add_child(arch)
		var slit := Palette.mi(Palette.box(0.25, 0.9, 0.1), dark, out + Vector3(0, top * 0.45, 0))
		slit.rotation.y = ang
		root.add_child(slit)
	root.add_child(Palette.mi(Palette.box(w + 0.36, 0.3, w + 0.36), Palette.stone(STONE_LIGHT), Vector3(0, top + 0.15, 0)))
	var spire := MeshInstance3D.new()
	spire.mesh = spire_mesh(w + 0.1, 4.2, 6)
	spire.material_override = glaze()
	spire.position = Vector3(0, top + 0.3, 0)
	root.add_child(spire)
	root.add_child(Palette.mi(Palette.sphere(0.16, 10, 8), Palette.mat(Color("d8b84a")), Vector3(0, top + 4.6, 0)))
	return root

static func castle_tower(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	var w := float(b.w)
	var h := float(b.h)
	var stone := Palette.stone(STONE)
	root.add_child(Palette.mi(Palette.box(w, h - 1.6 + 2.0, w), stone, Vector3(0, (h - 1.6) / 2.0 - 1.0, 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 6:
		var bx := rng.randf_range(-w / 2.0 + 0.35, w / 2.0 - 0.35)
		var bz := -w / 2.0 + 0.3 if k % 2 == 0 else w / 2.0 - 0.3
		var bh := rng.randf_range(0.3, 1.6)
		root.add_child(Palette.mi(Palette.box(0.7, bh, 0.6), stone, Vector3(bx, h - 1.6 + bh / 2.0, bz)))
	var dark := Palette.mat(SHADOW)
	for k in 3:
		root.add_child(Palette.mi(Palette.box(0.18, 0.8, 0.1), dark, Vector3(-0.6 + k * 0.6, 2.2 + k * 1.3, w / 2.0 + 0.01)))
	return root

static func tank(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	var w := float(b.w)
	var d := float(b.d)
	var stone := Palette.stone(STONE_LIGHT)
	var h := 1.1
	for sz in [-1.0, 1.0]:
		root.add_child(Palette.mi(Palette.box(w, h + 0.6, 0.3), stone, Vector3(0, h / 2.0 - 0.3, sz * (d / 2.0 - 0.15))))
	for sx in [-1.0, 1.0]:
		root.add_child(Palette.mi(Palette.box(0.3, h + 0.6, d), stone, Vector3(sx * (w / 2.0 - 0.15), h / 2.0 - 0.3, 0)))
	root.add_child(Palette.mi(Palette.box(w - 0.6, 0.06, d - 0.6), Palette.mat(Color("8f8270")), Vector3(0, 0.12, 0)))
	if Data.world_flags.has("olive_village_water_done"):
		root.add_child(Palette.mi(Palette.box(w - 0.62, 0.04, d - 0.62), Palette.mat(Color("4aa3b8")), Vector3(0, h - 0.3, 0)))
	return root

static func profile(floors: Array, x: float) -> float:
	var y := -INF
	for f in floors:
		if not f.get("walkable", true): continue
		var r: Array = f.rect
		if x < minf(r[0], r[2]) - 0.001 or x > maxf(r[0], r[2]) + 0.001: continue
		if f.has("rise"):
			var t := clampf((x - minf(r[0], r[2])) / absf(r[2] - r[0]), 0.0, 1.0)
			y = maxf(y, lerpf(float(f.rise[0]), float(f.rise[1]), t))
		else:
			y = maxf(y, float(f.top))
	return y

static func strip(xs: Array, lo: Array, hi: Array, z: float, thick: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [-1.0, 1.0]:
		var zf: float = z + face * thick / 2.0
		for i in xs.size() - 1:
			var q := [Vector3(xs[i], lo[i], zf), Vector3(xs[i + 1], lo[i + 1], zf), Vector3(xs[i + 1], hi[i + 1], zf), Vector3(xs[i], hi[i], zf)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[k])
	for i in xs.size() - 1:
		var t := [Vector3(xs[i], hi[i], z - thick / 2.0), Vector3(xs[i + 1], hi[i + 1], z - thick / 2.0), Vector3(xs[i + 1], hi[i + 1], z + thick / 2.0), Vector3(xs[i], hi[i], z + thick / 2.0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(t[k])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	return m

static func ribbon(xs: Array, ys: Array, z0: float, z1: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in xs.size() - 1:
		var q := [Vector3(xs[i], ys[i], z0), Vector3(xs[i + 1], ys[i + 1], z0), Vector3(xs[i + 1], ys[i + 1], z1), Vector3(xs[i], ys[i], z1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[k])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	return m

static func bridge(village: Node3D, floors: Array, z: float, half: float, spring: Vector2, rock_y: float) -> void:
	var walk := floors.filter(func(f): return f.get("walkable", true))
	if walk.is_empty(): return
	var x0 := INF
	var x1 := -INF
	for f in walk:
		x0 = minf(x0, minf(f.rect[0], f.rect[2]))
		x1 = maxf(x1, maxf(f.rect[0], f.rect[2]))
	var stone := two_sided(Palette.stone(STONE_LIGHT))
	var cap := two_sided(Palette.stone(Color("d8cfbd")))
	var deck := two_sided(Palette.stone(Color("b8ad99")))
	var under := two_sided(Palette.mat(Color("5b5a55")))
	var cx := (spring.x + spring.y) / 2.0
	var rx := (spring.y - spring.x) / 2.0
	var xs: Array = []
	var top: Array = []
	var arch: Array = []
	var x := x0
	while x <= x1 + 0.001:
		var y := profile(walk, x)
		xs.append(x)
		top.append(y)
		var u := (x - cx) / rx
		arch.append(rock_y + (y - 0.75 - rock_y) * sqrt(maxf(0.0, 1.0 - u * u)) if absf(u) < 1.0 else rock_y - 3.0)
		x += 0.2
	var parapet: Array = top.map(func(v): return v + 0.85)
	for side in [-1.0, 1.0]:
		var zc: float = z + side * (half + 0.17)
		village.add_child(strip(xs, arch, parapet, zc, 0.34, stone))
		village.add_child(strip(xs, parapet, parapet.map(func(v): return v + 0.08), zc, 0.42, cap))
	village.add_child(ribbon(xs, top.map(func(v): return v - 0.02), z - half, z + half, deck))
	village.add_child(ribbon(xs, arch, z - half, z + half, under))

static func covered_arch(span: float, depth: float, height: float) -> Node3D:
	var root := Node3D.new()
	var stone := Palette.stone(STONE)
	var ring := Palette.stone(STONE_LIGHT)
	var r := span / 2.0
	for side in [-1.0, 1.0]:
		root.add_child(Palette.mi(Palette.box(0.6, height + 1.0, depth), stone, Vector3(side * (r + 0.3), (height - 1.0) / 2.0, 0)))
	var n := 9
	for k in n:
		var a := PI * (float(k) + 0.5) / n
		var blk := Palette.mi(Palette.box(0.42, 0.3, depth + 0.06), ring, Vector3(cos(a) * (r + 0.1), height - 0.3 + sin(a) * (r * 0.55), 0))
		blk.rotation.z = a - PI / 2.0
		root.add_child(blk)
	var room_h := 2.4
	var base := height - 0.3 + r * 0.55 + 0.25
	root.add_child(Palette.mi(Palette.box(span + 1.6, room_h, depth), Palette.plaster(WHITEWASH), Vector3(0, base + room_h / 2.0, 0)))
	for sx in [-1.0, 1.0]:
		root.add_child(Palette.mi(Palette.box(0.3, room_h, depth + 0.04), stone, Vector3(sx * (span / 2.0 + 0.66), base + room_h / 2.0, 0)))
	gable(root, span + 1.6, depth, base + room_h, 0.6, 0.25, HouseKit.tile_material(TERRACOTTA))
	root.add_child(Palette.mi(Palette.box(span + 0.4, 0.1, depth), Palette.stone(STONE), Vector3(0, base - 0.05, 0)))
	return root

static func ferry() -> Node3D:
	var root := Node3D.new()
	var white := Palette.mat(Color("f4f1ea"))
	var blue := Palette.mat(Color("2f5f8f"))
	root.add_child(Palette.mi(Palette.box(2.6, 1.0, 8.0), white, Vector3(0, 0.3, 0)))
	root.add_child(Palette.mi(Palette.box(2.66, 0.3, 8.06), blue, Vector3(0, 0.05, 0)))
	var bow := Palette.mi(Palette.box(1.84, 1.0, 1.84), white, Vector3(0, 0.3, -4.0))
	bow.rotation.y = PI / 4.0
	bow.scale = Vector3(1.0, 1.0, 1.0)
	root.add_child(bow)
	root.add_child(Palette.mi(Palette.box(2.0, 1.6, 2.6), white, Vector3(0, 1.6, 1.4)))
	root.add_child(Palette.mi(Palette.box(2.1, 0.5, 2.7), Palette.mat(Color("39434d")), Vector3(0, 1.9, 1.4)))
	root.add_child(Palette.mi(Palette.box(2.2, 0.12, 2.8), blue, Vector3(0, 2.46, 1.4)))
	root.add_child(Palette.mi(Palette.cyl(0.08, 0.08, 1.2, 8), blue, Vector3(0, 3.0, 2.2)))
	for sx in [-1.0, 1.0]:
		root.add_child(Palette.mi(Palette.box(0.06, 0.5, 4.6), white, Vector3(sx * 1.25, 1.05, -1.6)))
	return root

static func jetty_stump() -> Node3D:
	var root := Node3D.new()
	var stone := Palette.stone(STONE)
	root.add_child(Palette.mi(Palette.box(2.4, 1.4, 2.6), stone, Vector3(0, -0.45, 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 7:
		var blk := Palette.mi(Palette.box(rng.randf_range(0.5, 0.9), rng.randf_range(0.3, 0.6), rng.randf_range(0.5, 0.9)), stone,
			Vector3(rng.randf_range(-1.6, 1.6), -0.35, 2.0 + k * 1.1))
		blk.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf(), rng.randf_range(-0.4, 0.4))
		root.add_child(blk)
	root.add_child(Palette.mi(Palette.cyl(0.12, 0.14, 1.6, 8), Palette.wood("7a5a40"), Vector3(0.9, 0.3, -0.9)))
	return root

static func sign_board(text: String) -> Node3D:
	var root := Node3D.new()
	var post := Palette.mat(Color("5a5f63"))
	for sx in [-0.55, 0.55]:
		root.add_child(Palette.mi(Palette.cyl(0.04, 0.04, 1.8, 8), post, Vector3(sx, 0.9, 0)))
	root.add_child(Palette.mi(Palette.box(1.5, 0.75, 0.05), Palette.mat(Color("f4f1ea")), Vector3(0, 1.55, 0)))
	root.add_child(Palette.mi(Palette.box(1.56, 0.81, 0.03), Palette.mat(Color("2f5f8f")), Vector3(0, 1.55, -0.02)))
	for face in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 64
		l.pixel_size = 0.0034
		l.modulate = Color("1f2a36")
		l.outline_size = 0
		l.position = Vector3(0, 1.55, face * 0.04)
		l.rotation.y = 0.0 if face > 0.0 else PI
		root.add_child(l)
	return root
