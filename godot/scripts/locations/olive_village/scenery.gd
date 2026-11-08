extends RefCounted

const Models := preload("models.gd")

const OLIVE_LEAVES := [Color("c2c9b0"), Color("b5bea3"), Color("cbd2bb"), Color("aeb89c")]
const FIG_LEAVES := [Color("5f8f3c"), Color("6e9a46"), Color("7aa64e")]
const BROOM := [Color("f8dc3a"), Color("f2d030"), Color("fbe45a"), Color("f0cf3e")]
const BRAMBLE := [Color("6a8548"), Color("5f7a42"), Color("74904e")]
const POPPY := Color("d63a2a")
const ROSE := [Color("e8798f"), Color("f2a3b3"), Color("d2546e")]
const HILLS := [Color("8c9a55"), Color("7d8f4a"), Color("6a7d3e"), Color("a39a5c")]

static var _meshes := {}

static func dress(village: Node3D) -> void:
	var ov: Script = Data.location_script(Data.island)
	var c: Dictionary = ov.get_script_constant_map()
	far_land(village, ov, c)
	bridge(village, ov, c)
	arches(village)
	trees(village)
	plants(village, ov, c)
	doorsteps(village)
	cove(village)
	population_sign(village)
	hill_villages(village, ov)

static func mm(village: Node3D, mesh: Mesh, mat: Material, xforms: Array, colors: Array = [], shadow: bool = true) -> void:
	if xforms.is_empty(): return
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = not colors.is_empty()
	m.mesh = mesh
	m.instance_count = xforms.size()
	for i in xforms.size():
		m.set_instance_transform(i, xforms[i])
		if m.use_colors: m.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = m
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	village.add_child(inst)

static func tint_mat(roughness: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	return m

static func props(kind: String) -> Array:
	return Data.layout.get("props", []).filter(func(p): return p.kind == kind)

static func far_land(village: Node3D, ov: Script, c: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := float(c.MAP_HALF)
	var reach := 360.0
	var step := 8.0
	var count := int(reach * 2.0 / step)
	var idx := 0
	for j in count:
		for i in count:
			var x0 := -reach + i * step
			var z0 := -reach + j * step
			var x1 := x0 + step
			var z1 := z0 + step
			if x0 >= -half and x1 <= half and z0 >= -half and z1 <= half: continue
			for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
				var y: float = ov.far_height(p.x, p.y)
				st.set_color(far_colour(p.x, p.y, y))
				st.add_vertex(Vector3(p.x, y, p.y))
			st.add_index(idx)
			st.add_index(idx + 1)
			st.add_index(idx + 2)
			st.add_index(idx + 1)
			st.add_index(idx + 3)
			st.add_index(idx + 2)
			idx += 4
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = village.terrain.material_override
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.name = "FarLand"
	village.add_child(m)

static func far_colour(x: float, z: float, y: float) -> Color:
	if y < 0.6: return Color("cfc6b4")
	var n := 0.5 + 0.5 * sin(x * 0.05 + cos(z * 0.04) * 2.0)
	var c: Color = HILLS[0].lerp(HILLS[2], Heightfield.ss(10.0, 40.0, y)).lerp(HILLS[3], 0.3 * n)
	return c.lerp(Color("8f8a7e"), Heightfield.ss(46.0, 60.0, y))

static func bridge(village: Node3D, ov: Script, c: Dictionary) -> void:
	var z: float = c.BRIDGE_Z
	var tc: float = ov.torrent_center(z)
	var hw: float = ov.torrent_half(z)
	Models.bridge(village, Data.layout.get("floors", []), z, c.BRIDGE_HALF, Vector2(tc - hw - 0.6, tc + hw + 0.6), 4.5)

static func arches(village: Node3D) -> void:
	for a in props("olive_village_arch"):
		var node := Models.covered_arch(float(a.span), float(a.depth), 3.0)
		var r := float(a.r)
		node.position = Vector3(a.x, Heightfield.height(a.x, a.z), a.z)
		node.rotation.y = atan2(-cos(r), sin(r))
		village.add_child(node)

static func canopy(kind: String) -> ArrayMesh:
	if _meshes.has(kind): return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blobs: Array = []
	var top := 2.8
	var bottom := 1.2
	if kind == "fig":
		blobs = [[Vector3(0, 2.2, 0), 1.3], [Vector3(1.0, 2.0, 0.4), 1.0], [Vector3(-1.0, 2.1, -0.4), 1.0], [Vector3(0.2, 2.8, 0.1), 0.9]]
		top = 3.4
	else:
		blobs = [[Vector3(0, 1.9, 0), 1.05], [Vector3(0.8, 1.7, 0.3), 0.8], [Vector3(-0.75, 1.75, -0.35), 0.8], [Vector3(0.2, 2.3, -0.2), 0.7], [Vector3(-0.3, 1.6, 0.75), 0.65]]
	for i in blobs.size():
		Foliage._blob(st, blobs[i][0], blobs[i][1], 23 + i * 11 + kind.length() * 5, 0.55, 1.0, top, bottom)
	_meshes[kind] = Foliage._finish(st)
	return _meshes[kind]

static func trees(village: Node3D) -> void:
	var by_kind := {}
	for t in props("olive_village_tree"): by_kind.get_or_add(String(t.tree), []).append(t)
	for kind in by_kind:
		var list: Array = by_kind[kind]
		var trunks: Array = []
		var tcols: Array = []
		var crowns: Array = []
		var ccols: Array = []
		var leaves: Array = FIG_LEAVES if kind == "fig" else OLIVE_LEAVES
		for t in list:
			var s := float(t.s)
			var y := Heightfield.height(t.x, t.z)
			var hue := float(t.hue)
			var lean := (hue - 0.5) * 0.4
			trunks.append(Transform3D(Basis.from_euler(Vector3(lean, hue * TAU, lean * 0.7)).scaled(Vector3(1, s, 1)), Vector3(t.x, y + 0.8 * s, t.z)))
			tcols.append(Color("6f6355") if kind == "olive" else Color("a39a8a"))
			crowns.append(Transform3D(Basis.from_euler(Vector3(0, hue * TAU, 0)).scaled(Vector3.ONE * s), Vector3(t.x, y - 0.05, t.z)))
			ccols.append(leaves[int(hue * leaves.size()) % leaves.size()])
			village.occluders.append([Vector3(t.x, y + 2.0 * s, t.z), 1.2 * s])
		mm(village, Palette.cyl(0.1, 0.2, 1.6, 7), tint_mat(), trunks, tcols)
		mm(village, canopy(kind), Foliage.plant_material(0.015, 1.0), crowns, ccols)

static func spot_ok(ov: Script, x: float, z: float) -> bool:
	var h := Heightfield.height(x, z)
	if h < 0.4: return false
	if ov.steep(x, z, h): return false
	if Heightfield.paint(x, z).a < 0.2: return false
	for zn in Data.layout.zones:
		if x > zn.minI - 0.5 and x < zn.maxI + 1.5 and z > zn.minK - 0.5 and z < zn.maxK + 1.5: return false
	for b in Data.layout.buildings:
		if absf(x - b.x) < b.w / 2.0 + 0.8 and absf(z - b.z) < b.d / 2.0 + 0.8: return false
	return true

static func scatter(ov: Script, rng: RandomNumberGenerator, box: Rect2, n: int, tries: int) -> Array:
	var out: Array = []
	var k := 0
	while out.size() < n and k < tries:
		k += 1
		var x := rng.randf_range(box.position.x, box.end.x)
		var z := rng.randf_range(box.position.y, box.end.y)
		if spot_ok(ov, x, z): out.append(Vector3(x, Heightfield.height(x, z), z))
	return out

static func plants(village: Node3D, ov: Script, c: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var broom: Array = []
	for box in [Rect2(30, -80, 50, 40), Rect2(-80, -40, 28, 90), Rect2(40, 38, 38, 18), Rect2(-60, 26, 50, 26)]:
		broom.append_array(scatter(ov, rng, box, 45, 900))
	var bx: Array = []
	var bc: Array = []
	for p in broom:
		var s := rng.randf_range(0.8, 1.5)
		bx.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s * 1.1, s * 0.9, s * 1.1)), p - Vector3(0, 0.05, 0)))
		bc.append(BROOM[rng.randi() % BROOM.size()])
	mm(village, Foliage.bush(), Foliage.plant_material(0.03, 0.1), bx, bc)
	var bramble := scatter(ov, rng, Rect2(24, -62, 54, 16), 70, 1400)
	var rx: Array = []
	var rc: Array = []
	for p in bramble:
		var s := rng.randf_range(0.9, 1.6)
		rx.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s * 1.3, s * 0.7, s * 1.3)), p - Vector3(0, 0.05, 0)))
		rc.append(BRAMBLE[rng.randi() % BRAMBLE.size()])
	mm(village, Foliage.bush(), Foliage.plant_material(0.02, 0.1), rx, rc)
	var poppies := scatter(ov, rng, Rect2(24, -60, 54, 32), 520, 4000)
	poppies.append_array(scatter(ov, rng, Rect2(-62, -40, 20, 70), 120, 1200))
	var px: Array = []
	var pc: Array = []
	for p in poppies:
		px.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(1.3, 1.9)), p + Vector3(0, 0.25, 0)))
		pc.append(POPPY.lerp(Color("e8582a"), rng.randf() * 0.4))
	mm(village, Foliage.flower_head(), Foliage.plant_material(0.02, -1.0, false, true), px, pc, false)

static func door_spot(b: Dictionary) -> Array:
	var side := String(b.get("door", "S"))
	var w := float(b.w)
	var d := float(b.d)
	match side:
		"N": return [Vector2(b.x, b.z - d / 2.0 - 0.35), Vector2(1, 0)]
		"E": return [Vector2(b.x + w / 2.0 + 0.35, b.z), Vector2(0, 1)]
		"W": return [Vector2(b.x - w / 2.0 - 0.35, b.z), Vector2(0, 1)]
	return [Vector2(b.x, b.z + d / 2.0 + 0.35), Vector2(1, 0)]

static func doorsteps(village: Node3D) -> void:
	var pots: Array = []
	var leaves: Array = []
	var bushes: Array = []
	var blooms: Array = []
	var bloom_cols: Array = []
	var n := 0
	for b in Data.layout.buildings:
		if not b.get("kit", false): continue
		n += 1
		var ds: Array = door_spot(b)
		var at: Vector2 = ds[0]
		var along: Vector2 = ds[1]
		for sgn in [-1.0, 1.0]:
			var p: Vector2 = at + along * sgn * 0.95
			var y := Heightfield.height(p.x, p.y)
			pots.append(Transform3D(Basis.IDENTITY, Vector3(p.x, y + 0.14, p.y)))
			leaves.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 0.45, 0.55)), Vector3(p.x, y + 0.26, p.y)))
		if n % 3 != 0: continue
		var corner := Vector2(b.x + float(b.w) / 2.0 + 0.2, b.z + float(b.d) / 2.0 + 0.2)
		var cy := Heightfield.height(corner.x, corner.y)
		bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.7, 2.2, 0.7)), Vector3(corner.x, cy - 0.05, corner.y)))
		for k in 9:
			var a := k * 2.1
			blooms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.5), Vector3(corner.x + cos(a) * 0.35, cy + 0.6 + k * 0.28, corner.y + sin(a) * 0.35)))
			bloom_cols.append(ROSE[k % ROSE.size()])
	mm(village, Palette.cyl(0.16, 0.12, 0.28, 10), Palette.mat(Color("b8643c")), pots)
	mm(village, Foliage.bush(), Foliage.plant_material(0.02, 0.0), leaves, leaves.map(func(_l): return Color("4f8a3a")))
	mm(village, Foliage.bush(), Foliage.plant_material(0.02, 0.2), bushes, bushes.map(func(_l): return Color("4c7a3a")))
	mm(village, Foliage.flower_head(), Foliage.plant_material(0.02, -1.0, false, true), blooms, bloom_cols, false)

static func cove(village: Node3D) -> void:
	var ferry := Models.ferry()
	ferry.position = Vector3(19.5, Heightfield.WATER_Y - 0.15, 76.0)
	ferry.rotation.y = 0.35
	village.add_child(ferry)
	var stump := Models.jetty_stump()
	stump.position = Vector3(22.0, Heightfield.height(22.0, 60.4), 60.4)
	village.add_child(stump)
	for b in props("olive_village_boat"):
		var boat := Node3D.new()
		var hull := Palette.mat(Color(String(b.get("color", "2f5f8f"))))
		boat.add_child(Palette.mi(Palette.box(float(b.w), 0.5, float(b.d) - 0.6), hull, Vector3(0, 0.25, 0.2)))
		var bow := Palette.mi(Palette.box(float(b.w) * 0.7, 0.5, float(b.w) * 0.7), hull, Vector3(0, 0.25, -float(b.d) / 2.0 + 0.5))
		bow.rotation.y = PI / 4.0
		boat.add_child(bow)
		boat.add_child(Palette.mi(Palette.box(float(b.w) - 0.2, 0.06, float(b.d) - 1.0), Palette.wood("c49a6c"), Vector3(0, 0.42, 0.2)))
		boat.position = Vector3(b.x, Heightfield.height(b.x, b.z), b.z)
		boat.rotation.y = float(b.get("r", 0.0))
		village.add_child(boat)

static func population_sign(village: Node3D) -> void:
	for f in Data.layout.features:
		if f.id != "olive_village_sign": continue
		var post: Node3D = village.objects.get(f.id)
		if post: post.visible = false
		var reading := LocationMeter.reading(LocationMeter.def(Data.island), 0)
		var board := Models.sign_board("LIOLIVATO\n" + reading)
		board.position = Vector3(f.x, Heightfield.height(f.x, f.z), f.z)
		board.rotation.y = float(f.get("rot", 0.0))
		village.add_child(board)

static func hill_villages(village: Node3D, ov: Script) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var walls: Array = []
	var roofs: Array = []
	for c in [Vector2(-210, -170), Vector2(-120, -255), Vector2(150, -230), Vector2(255, -120), Vector2(-285, 10)]:
		for k in 9:
			var x: float = c.x + rng.randf_range(-14.0, 14.0)
			var z: float = c.y + rng.randf_range(-10.0, 10.0)
			var y: float = ov.far_height(x, z)
			var s := rng.randf_range(2.6, 4.2)
			var h := rng.randf_range(4.0, 7.0)
			walls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, h, s)), Vector3(x, y + h / 2.0 - 0.5, z)))
			roofs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s + 0.5, 0.6, s + 0.5)), Vector3(x, y + h - 0.2, z)))
		var ty: float = ov.far_height(c.x, c.y)
		walls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.2, 12.0, 2.2)), Vector3(c.x, ty + 5.5, c.y)))
	mm(village, Palette.box(1, 1, 1), Palette.plaster(Color("efe7d6")), walls, [], false)
	mm(village, Palette.box(1, 1, 1), Palette.mat(Color("b8643c")), roofs, [], false)
