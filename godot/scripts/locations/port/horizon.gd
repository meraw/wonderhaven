extends RefCounted

const P := preload("../../world/palette.gd")
const Palazzo := preload("palazzo.gd")

const EDGE := 150.0
const FAR := 520.0
const STEP := 10.0
const PORT_X := -175.0
const WALLS := ["a8473a", "d4a24c", "e09a7a", "e9d39a", "e0b98a", "c98a6a", "d9c9a8"]

static func ground(x: float, z: float, map_height: Callable) -> float:
	if absf(x) < EDGE and absf(z) < EDGE: return -20.0
	var n := 6.0 * sin(x * 0.021 + 0.7) * cos(z * 0.017) + 3.0 * sin(x * 0.051 + z * 0.043)
	var north := -20.0
	if z < -EDGE + 0.1:
		var edge_x := clampf(x, -EDGE + 0.1, EDGE - 0.1)
		var start := maxf(float(map_height.call(edge_x, -EDGE + 0.1)), 30.0)
		var into := -EDGE - z
		north = start + into * 0.8 + n * clampf(into / 40.0, 0.0, 1.0)
		if x > 200.0: north = minf(north, 40.0 + into * 0.6 + n)
	var west := -20.0
	if x < -EDGE and z < 120.0:
		if x < PORT_X - 85.0:
			west = 2.0 + (PORT_X - 85.0 - x) * 0.5 + n
		elif x < PORT_X:
			west = 1.6
	var east := -20.0
	if x > 250.0 and z < -40.0 + (x - 250.0) * 0.15 and z > -EDGE - 10.0:
		east = 6.0 + (x - 250.0) * 0.35 + n * 0.6
	return maxf(north, maxf(west, east))

static func dress(village: Node3D, map_height: Callable) -> void:
	var root := Node3D.new()
	root.name = "port_horizon"
	village.add_child(root)
	root.add_child(land(map_height))
	city(root, map_height)
	forts(root, map_height)
	harbour(root)

static func land(map_height: Callable) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(FAR * 2.0 / STEP)
	var hs: Array = []
	for j in n + 1:
		var row: Array = []
		for i in n + 1:
			var x := -FAR + i * STEP
			var z := -FAR + j * STEP
			row.append(ground(x, z, map_height))
		hs.append(row)
	var green := Color("4f6a3a")
	var scrub := Color("6f7448")
	var rock := Color("8a847a")
	var town := Color("9a8466")
	for j in n:
		for i in n:
			var quad := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var hi := -100.0
			for q in quad:
				var qq: Vector2i = q
				hi = maxf(hi, float(hs[qq.y][qq.x]))
			if hi < -1.0: continue
			var verts: Array = []
			var cols: Array = []
			for q in quad:
				var qi: Vector2i = q
				var x: float = -FAR + qi.x * STEP
				var z: float = -FAR + qi.y * STEP
				var y := maxf(float(hs[qi.y][qi.x]), -1.2)
				verts.append(Vector3(x, y, z))
				var c := green.lerp(scrub, clampf(sin(x * 0.03 + z * 0.02) * 0.5 + 0.5, 0.0, 1.0))
				if y < 70.0 and (x < PORT_X - 80.0 or z < -EDGE - 5.0) and x < 120.0: c = c.lerp(town, 0.55 * (1.0 - clampf(y / 70.0, 0.0, 1.0)))
				if y > 160.0: c = c.lerp(rock, clampf((y - 160.0) / 80.0, 0.0, 1.0))
				if y < 0.0: c = Color("5a6a62")
				cols.append(c)
			for tri in [[0, 2, 1], [0, 3, 2]]:
				for k in tri:
					st.set_color(cols[k])
					st.add_vertex(verts[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.name = "port_far_land"
	return mi

static func _multi(root: Node3D, items: Array, mat: Material, name: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = HouseKit.unit_box()
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.name = name
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)

static func city(root: Node3D, map_height: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2002
	var walls: Array = []
	var roofs: Array = []
	var x := -FAR
	while x < 140.0:
		var z := -FAR
		while z < EDGE:
			var px := x + rng.randf_range(-3.0, 3.0)
			var pz := z + rng.randf_range(-3.0, 3.0)
			var y := ground(px, pz, map_height)
			var in_city := (px < PORT_X - 88.0) or (pz < -EDGE - 8.0)
			if in_city and y > 3.0 and y < 85.0 and rng.randf() < 0.85 - y / 120.0:
				var w := rng.randf_range(7.0, 13.0)
				var d := rng.randf_range(7.0, 11.0)
				var h := rng.randf_range(9.0, 21.0)
				var yaw := rng.randf_range(-0.25, 0.25)
				var basis := Basis(Vector3.UP, yaw)
				var wall := Color(WALLS[rng.randi() % WALLS.size()]).darkened(rng.randf_range(0.0, 0.15))
				walls.append([Transform3D(basis * Basis.from_scale(Vector3(w, h + 4.0, d)), Vector3(px, y + h / 2.0 - 2.0, pz)), wall])
				roofs.append([Transform3D(basis * Basis.from_scale(Vector3(w + 0.6, 0.8, d + 0.6)), Vector3(px, y + h + 0.4, pz)), Color("5d636a").darkened(rng.randf_range(0.0, 0.2))])
			z += 12.0
		x += 12.0
	_multi(root, walls, Palazzo.tinted("plaster"), "port_city_walls")
	_multi(root, roofs, Palazzo.tinted("slate"), "port_city_roofs")

static func forts(root: Node3D, map_height: Callable) -> void:
	var stone := P.stone("9a958c")
	var spots := [[-360.0, -330.0], [-170.0, -360.0], [40.0, -390.0], [-430.0, -120.0], [-260.0, -250.0]]
	for idx in spots.size():
		var x: float = spots[idx][0]
		var z: float = spots[idx][1]
		var y := ground(x, z, map_height)
		var fort := Node3D.new()
		fort.name = "port_fort%d" % idx
		fort.position = Vector3(x, y - 1.0, z)
		root.add_child(fort)
		for s in [[0.0, -9.0, 22.0, 2.0], [0.0, 9.0, 22.0, 2.0], [-10.0, 0.0, 2.0, 18.0], [10.0, 0.0, 2.0, 18.0]]:
			fort.add_child(P.mi(P.box(float(s[2]), 7.0, float(s[3])), stone, Vector3(float(s[0]), 3.5, float(s[1])), false))
		for cx in [-10.0, 10.0]:
			for cz in [-9.0, 9.0]:
				fort.add_child(P.mi(P.box(4.0, 9.0, 4.0), stone, Vector3(cx, 4.5, cz), false))
		fort.add_child(P.mi(P.box(8.0, 10.0, 8.0), stone, Vector3(0, 5.0, 0), false))

static func harbour(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1999
	var quay := P.stone("a39d90")
	root.add_child(P.mi(P.box(85.0, 2.4, 300.0), quay, Vector3(PORT_X - 42.0, 0.6, -10.0), false))
	for mz in [-110.0, -50.0, 10.0, 70.0]:
		root.add_child(P.mi(P.box(60.0, 2.2, 22.0), quay, Vector3(PORT_X - 2.0, 0.5, mz), false))
	var boxes: Array = []
	var cols := ["c8302c", "2f6fa0", "d4a24c", "3f7a4a", "8a8a86", "e09a3a", "6a4a8a"]
	for mz in [-110.0, -50.0, 10.0, 70.0]:
		for k in 40:
			var px := PORT_X - 26.0 + (k % 10) * 6.4
			var pz: float = float(mz) - 7.0 + floorf(k / 10.0) * 3.0
			var stack := rng.randi_range(1, 3)
			for s in stack:
				boxes.append([Transform3D(Basis.from_scale(Vector3(6.0, 2.5, 2.4)), Vector3(px, 1.6 + 1.25 + s * 2.55, pz)), Color(cols[rng.randi() % cols.size()]).darkened(rng.randf_range(0.0, 0.2))])
	_multi(root, boxes, Palazzo.tinted("plaster"), "port_containers")
	for k in 6:
		var z := -125.0 + k * 50.0
		crane(root, Vector3(PORT_X + 6.0, 1.6, z + 12.0), ["c8302c", "2f6fa0", "d4a24c"][k % 3], k)
	for k in 5:
		var z := -80.0 + k * 40.0
		var w := P.mi(P.box(30.0, 9.0, 18.0), P.stone("9a9a96"), Vector3(PORT_X - 60.0, 5.6, z), false)
		root.add_child(w)
	ship(root, Vector3(PORT_X + 12.0, -0.4, -78.0), 70.0, "2b3a4a", false, 0)
	ship(root, Vector3(PORT_X + 12.0, -0.4, 38.0), 60.0, "6a2a2a", false, 1)
	ship(root, Vector3(PORT_X + 8.0, -0.4, 100.0), 90.0, "f2efe6", true, 2)

static func crane(root: Node3D, base: Vector3, color: String, idx: int) -> void:
	var mat := P.mat(color)
	var g := Node3D.new()
	g.name = "port_crane%d" % idx
	g.position = base
	root.add_child(g)
	for lx in [-5.0, 5.0]:
		for lz in [-4.0, 4.0]:
			g.add_child(P.mi(P.box(0.8, 28.0, 0.8), mat, Vector3(lx, 14.0, lz), false))
	g.add_child(P.mi(P.box(11.0, 1.4, 9.0), mat, Vector3(0, 28.0, 0), false))
	g.add_child(P.mi(P.box(48.0, 1.6, 2.0), mat, Vector3(14.0, 29.5, 0), false))
	g.add_child(P.mi(P.box(4.0, 3.0, 3.0), P.mat("e8e4dc"), Vector3(0, 31.0, 0), false))

static func ship(root: Node3D, pos: Vector3, length: float, hull: String, ferry: bool, idx: int) -> void:
	var g := Node3D.new()
	g.name = "port_ferry" if ferry else "port_ship%d" % idx
	g.position = pos
	root.add_child(g)
	var beam := 14.0 if ferry else 12.0
	g.add_child(P.mi(P.box(beam, 7.0, length), P.mat(hull), Vector3(0, 1.5, 0), false))
	if ferry:
		for k in 4:
			g.add_child(P.mi(P.box(beam - 1.0 - k * 1.0, 2.6, length * (0.8 - k * 0.12)), P.mat("f7f4ee"), Vector3(0, 6.3 + k * 2.6, -length * 0.05), false))
		g.add_child(P.mi(P.box(beam + 0.05, 0.8, length * 0.9), P.mat("2f6fa0"), Vector3(0, 4.6, 0), false))
		g.add_child(P.mi(P.box(3.0, 5.0, 4.0), P.mat("c8302c"), Vector3(0, 18.0, -length * 0.2), false))
	else:
		g.add_child(P.mi(P.box(beam - 2.0, 9.0, 12.0), P.mat("f2efe6"), Vector3(0, 9.5, -length * 0.38), false))
		g.add_child(P.mi(P.box(3.0, 5.0, 3.0), P.mat("2b2b2e"), Vector3(0, 16.0, -length * 0.42), false))
		var cols := ["c8302c", "2f6fa0", "d4a24c", "3f7a4a"]
		for k in 8:
			g.add_child(P.mi(P.box(beam - 2.0, 2.4, 5.6), P.mat(cols[k % cols.size()]), Vector3(0, 6.2, -length * 0.25 + k * 6.0), false))
