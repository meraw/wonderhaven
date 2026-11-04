extends RefCounted
## Boccapioppo's scenery (docs/locations/river_town.md, "Look"), added after the shared world is built:
## - trees: hybrid poplars in the plantation, Lombardy column poplars along the avenue and the canals, white
##   willows on the banks, black locust thickets and a few big old trees, all golden with autumn. Their trunks are
##   the layout's invisible `river_town_tree` props, so they block you like the shared trees. The eight chopping trees
##   become poplars too.
## - the Roman bridge, the sawmill's open shed, the station's track, the river gauge, the flood's leftovers (the
##   flooded piazza, mud, debris, Tullio's sunken ferry, the sandbag patch), leaning bicycles, reeds, maize stubble;
## - the horizon: the Alps to the north, lines of poplars and other villages' bell towers across the plain, the first
##   Apennine hills beyond the Po.
const P := preload("res://scripts/world/palette.gd")

static var _meshes: Dictionary = {}

static func dress(village: Node3D, rt) -> void:
	_clear_greenery(village, Vector2(rt.PIAZZA.x, rt.PIAZZA.z), rt.PIAZZA_R + 0.4)
	_trees(village)
	_chop_trees(village)
	_roman_bridge(village, rt)
	_shed(village)
	_track(village, rt)
	_gauge(village)
	_flood(village, rt)
	_bikes(village)
	_reeds(village, rt)
	_stubble(village)
	_horizon(village, rt)

static func H(x: float, z: float) -> float: return Heightfield.height(x, z)

## No grass or flowers in the flooded piazza: flatten the shared greenery's instances that stand in it. (Once paved
## ground keeps greenery off squares for every location, this does nothing.)
static func _clear_greenery(village: Node3D, c: Vector2, r: float) -> void:
	for mmi in village.get_children():
		if not mmi is MultiMeshInstance3D: continue
		var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			if Vector2(o.x - c.x, o.z - c.y).length() < r: mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), o))

static func _props(kind: String) -> Array:
	return Data.layout.get("props", []).filter(func(p): return p.kind == kind)

static func _mm(village: Node3D, mesh: Mesh, mat: Material, xforms: Array, colors: Array = [], shadow: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors: mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new(); inst.multimesh = mm; inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	village.add_child(inst)
	return inst

static func _tint_mat(roughness: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true; m.roughness = roughness
	return m

# ---- trees -------------------------------------------------------------------------------------------------------

## Canopy meshes, built from the shared foliage blobs (dark underneath, bright on top), origin at the ground.
static func canopy(kind: String) -> ArrayMesh:
	if _meshes.has(kind): return _meshes[kind]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blobs: Array = []
	var top := 1.0; var bottom := 0.0
	match kind:
		"poplar":   # a tall oval crown on a long straight trunk
			blobs = [[Vector3(0, 4.4, 0), 1.25], [Vector3(0.35, 5.4, 0.2), 1.2], [Vector3(-0.3, 6.3, -0.15), 1.05], [Vector3(0.1, 7.2, 0.1), 0.8], [Vector3(-0.45, 4.9, 0.45), 0.9]]
			top = 8.0; bottom = 3.3
		"column":   # the Lombardy poplar: a slender column of leaves from low on the trunk to a point
			for k in 11: blobs.append([Vector3(sin(k * 1.7) * 0.06, 1.3 + k * 0.66, cos(k * 1.3) * 0.06), 0.78 - k * 0.042])
			top = 8.4; bottom = 0.8
		"willow":   # a wide, loose, silvery crown with drooping skirts
			blobs = [[Vector3(0, 3.0, 0), 1.5], [Vector3(1.0, 2.6, 0.4), 1.15], [Vector3(-1.0, 2.7, -0.3), 1.15], [Vector3(0.3, 2.4, -1.0), 1.0], [Vector3(-0.3, 2.3, 1.0), 1.0], [Vector3(0, 3.7, 0), 0.9]]
			top = 4.5; bottom = 1.2
		"locust":   # a small airy crown in a few clumps
			blobs = [[Vector3(0, 2.7, 0), 0.8], [Vector3(0.65, 2.4, 0.3), 0.6], [Vector3(-0.55, 2.5, -0.35), 0.62], [Vector3(0.1, 3.2, -0.2), 0.55]]
			top = 3.6; bottom = 1.8
		_:          # "plane": a big old shade tree in a town garden
			blobs = [[Vector3(0, 3.6, 0), 1.6], [Vector3(1.1, 3.2, 0.5), 1.15], [Vector3(-1.0, 3.3, -0.6), 1.2], [Vector3(0.2, 4.4, -0.2), 1.1], [Vector3(-0.5, 3.0, 1.0), 1.0]]
			top = 5.4; bottom = 2.2
	for i in blobs.size():
		Foliage._blob(st, blobs[i][0], blobs[i][1], 41 + i * 13 + kind.length() * 7, 0.55, 1.0, top, bottom)
	_meshes[kind] = Foliage._finish(st)
	return _meshes[kind]

const TRUNK := {"poplar": [0.11, 0.17, 4.4, "d8d2c4"], "column": [0.12, 0.2, 1.6, "8f8576"], "willow": [0.2, 0.3, 2.4, "7a6d5c"], "locust": [0.07, 0.11, 2.4, "5f5246"], "plane": [0.18, 0.26, 3.0, "b8ad94"]}
const LEAVES := {
	"poplar": ["e3c04e", "d6b444", "ebcb62", "c9b04a", "b9c05a"],
	"column": ["e6c654", "dcbc4c", "c9c766", "efd06c"],
	"willow": ["cdd8ae", "c2cfa2", "d6dcb2", "d2d39e"],
	"locust": ["dcd882", "ccd078", "e4dc8e"],
	"plane": ["e6a650", "eebc64", "d89048", "e2c060"]}

static func _trees(village: Node3D) -> void:
	var by_kind := {}
	for t in _props("river_town_tree"): by_kind.get_or_add(String(t.tree), []).append(t)
	for kind in by_kind:
		var list: Array = by_kind[kind]
		var tr: Array = TRUNK[kind]
		var trunks: Array = []; var tcols: Array = []; var crowns: Array = []; var ccols: Array = []
		for t in list:
			var s := float(t.s)
			var y := H(t.x, t.z)
			var lean := (float(t.hue) - 0.5) * (0.35 if kind == "willow" else 0.06)
			trunks.append(Transform3D(Basis.from_euler(Vector3(lean, 0, lean * 0.6)).scaled(Vector3(1, s, 1)), Vector3(t.x, y + tr[2] * s / 2.0, t.z)))
			tcols.append(Color(tr[3]))
			crowns.append(Transform3D(Basis.from_euler(Vector3(0, float(t.hue) * TAU, 0)).scaled(Vector3.ONE * s), Vector3(t.x, y - 0.05, t.z)))
			var cl: Array = LEAVES[kind]
			ccols.append(Color(cl[int(float(t.hue) * cl.size()) % cl.size()]))
			var mid: float = {"poplar": 5.6, "column": 4.6, "willow": 2.9, "locust": 2.7, "plane": 3.7}[kind]
			if t.get("solid", true): village.occluders.append([Vector3(t.x, y + mid * s, t.z), (1.4 if kind != "column" else 0.9) * s])
		_mm(village, P.cyl(tr[0], tr[1], tr[2], 7), _tint_mat(), trunks, tcols)
		_mm(village, canopy(kind), Foliage.plant_material(0.02, 1.0), crowns, ccols)

## The chopping trees stand in the plantation's rows: give them a poplar's trunk and crown (the forester's ribbon
## stays).
static func _chop_trees(village: Node3D) -> void:
	for n in Data.layout.nodes:
		if n.kind != "chop": continue
		var o: Node3D = village.node_visuals.get(n.id)
		if o == null: continue
		for c in o.get_children():
			if c.name != "ribbon": c.queue_free()
		var tr: Array = TRUNK["poplar"]
		Props._add(o, P.cyl(tr[0], tr[1], tr[2], 8), P.wood(tr[3]), Vector3(0, tr[2] / 2.0, 0))
		var leaf := Props.leaf_mat(Color(LEAVES["poplar"][int(absf(n.z)) % 5]))
		Props._add(o, canopy("poplar"), leaf, Vector3(0, -0.05, 0), Vector3(0, n.x, 0))

# ---- landmarks -----------------------------------------------------------------------------------------------------

## The Roman bridge: three stone arches springing from piers with pointed cutwaters, a hump-backed deck over the
## walkway the ground script shapes, low parapets with cap stones. Its arches open onto dark shadow.
static func _roman_bridge(village: Node3D, rt) -> void:
	var z0: float = rt.ROMAN_Z; var half: float = rt.ROMAN_HALF
	var ac: float = rt.alpine_center(z0)
	var stone := P.stone("cbbfa8"); var cap := P.stone("ddd2bd"); var shadow := P.mat("2e3330")
	var x0 := ac - 8.0; var x1 := ac + 8.0
	var spans := [[ac - 5.1, ac - 1.75], [ac - 1.65, ac + 1.65], [ac + 1.75, ac + 5.1]]
	var step := 0.25
	var x := x0
	while x < x1 - 0.001:
		var xc := x + step / 2.0
		var top := H(xc, z0)
		var bottom := -1.0
		for s in spans:
			if xc > s[0] and xc < s[1]:
				var r: float = (s[1] - s[0]) / 2.0
				var m: float = (s[0] + s[1]) / 2.0
				var u := (xc - m) / r
				bottom = -0.35 + r * 0.95 * sqrt(maxf(0.0, 1.0 - u * u))
				village.add_child(P.mi(P.box(step, bottom + 0.4, 0.04), shadow, Vector3(xc, (bottom - 0.4) / 2.0, z0 - half + 0.12)))
				village.add_child(P.mi(P.box(step, bottom + 0.4, 0.04), shadow, Vector3(xc, (bottom - 0.4) / 2.0, z0 + half - 0.12)))
		for zs in [-1.0, 1.0]:
			village.add_child(P.mi(P.box(step + 0.01, top - bottom, 0.3), stone, Vector3(xc, (top + bottom) / 2.0, z0 + zs * (half + 0.05))))
			village.add_child(P.mi(P.box(step + 0.01, 0.5, 0.26), stone, Vector3(xc, top + 0.25, z0 + zs * (half + 0.08))))
			village.add_child(P.mi(P.box(step + 0.02, 0.08, 0.34), cap, Vector3(xc, top + 0.52, z0 + zs * (half + 0.08))))
		x += step
	for px in [ac - 1.7, ac + 1.7]:   # cutwaters against the current, upstream (north) and down
		for zs in [-1.0, 1.0]:
			var cw := P.mi(P.box(0.9, 1.6, 0.9), stone, Vector3(px, -0.2, z0 + zs * (half + 0.45)))
			cw.rotation.y = PI / 4; village.add_child(cw)
	# flood debris caught against the piers upstream
	var wood := P.wood("6b5440")
	for k in 6:
		var b := P.mi(P.cyl(0.08, 0.12, 2.4 + k * 0.3, 6), wood, Vector3(ac - 2.2 + k * 0.9, -0.3 + 0.08 * (k % 2), z0 - half - 0.9 - 0.2 * (k % 3)))
		b.rotation = Vector3(PI / 2 + 0.2 * (k % 2), 0.4 * (k - 3), 0.1 * k); village.add_child(b)

## The sawmill's open shed: a sloping roof on timber posts over the saw bench, log piles and stacked planks.
static func _shed(village: Node3D) -> void:
	var posts := _props("river_town_post")
	if posts.is_empty(): return
	var timber := P.wood("7a5a3c")
	var y0 := H(43.0, 20.0)
	for p in posts: village.add_child(P.mi(P.box(0.3, 3.4, 0.3), timber, Vector3(p.x, y0 + 1.7, p.z)))
	var roof := P.mi(P.box(8.0, 0.14, 9.2), P.mat("7d6b58"), Vector3(43.0, y0 + 3.55, 20.0)); roof.rotation.z = 0.12; village.add_child(roof)
	for k in 9: village.add_child(P.mi(P.box(8.05, 0.04, 0.06), P.mat("5f4f40"), Vector3(43.0, y0 + 3.64 + 0.0, 16.0 + k * 1.0)))
	for s in _props("river_town_saw"):
		var hy := H(s.x, s.z)
		village.add_child(P.mi(P.box(2.6, 0.85, 1.0), timber, Vector3(s.x, hy + 0.42, s.z)))
		var blade := P.mi(P.cyl(0.55, 0.55, 0.03, 24), P.mat("c9ccd0"), Vector3(s.x, hy + 0.95, s.z)); blade.rotation.x = PI / 2; village.add_child(blade)
		village.add_child(P.mi(P.cyl(0.2, 0.4, 0.3, 10), P.mat("e3cf9a"), Vector3(s.x + 1.6, hy + 0.15, s.z + 0.6)))   # sawdust
	var bark := P.wood("a59c8c"); var cut := P.wood("e8d3a3")
	for l in _props("river_town_logs"):
		var hy := H(l.x, l.z)
		for row in 3:
			for k in 4 - row:
				var lg := P.mi(P.cyl(0.24, 0.24, 2.6, 10), bark, Vector3(l.x - 0.75 + k * 0.5 + row * 0.25, hy + 0.24 + row * 0.42, l.z)); lg.rotation.x = PI / 2; village.add_child(lg)
				for e in [-1.0, 1.0]:
					var end := P.mi(P.cyl(0.22, 0.22, 0.02, 10), cut, Vector3(l.x - 0.75 + k * 0.5 + row * 0.25, hy + 0.24 + row * 0.42, l.z + e * 1.31)); end.rotation.x = PI / 2; village.add_child(end)
	for pl in _props("river_town_planks"):
		var hy := H(pl.x, pl.z)
		for k in 6: village.add_child(P.mi(P.box(2.2, 0.08, 0.9), cut, Vector3(pl.x, hy + 0.1 + k * 0.1, pl.z), true))
	# the portico columns of the arcade and the station canopy are drawn by the buildings; the props only collide

## The valley railway's track: sleepers and rails up the embankment from a buffer stop by the station, north over
## the canal on a small iron bridge, and on across the plain.
static func _track(village: Node3D, rt) -> void:
	var x: float = rt.RAIL_X
	var z := rt.RAIL_SOUTH as float
	var sleepers: Array = []; var rails: Array = []
	var zz := z
	while zz > -200.0:
		var y: float = H(x, zz) if zz > -62.0 else rt.TOWN_H + 0.47
		if zz > rt.CANAL_N - rt.CANAL_HALF - 1.2 and zz < rt.CANAL_N + rt.CANAL_HALF + 1.2: y = rt.TOWN_H + 0.5
		sleepers.append(Transform3D(Basis(), Vector3(x, y + 0.04, zz)))
		zz -= 0.7
	_mm(village, P.box(1.8, 0.08, 0.24), P.wood("6b5440"), sleepers)
	for s in [-0.55, 0.55]:
		var seg := 2.0
		zz = z
		while zz > -200.0:
			var y: float = H(x, zz - seg / 2.0) if zz > -62.0 else rt.TOWN_H + 0.47
			if zz - seg / 2.0 > rt.CANAL_N - rt.CANAL_HALF - 1.2 and zz - seg / 2.0 < rt.CANAL_N + rt.CANAL_HALF + 1.2: y = rt.TOWN_H + 0.5
			rails.append(Transform3D(Basis(), Vector3(x + s, y + 0.13, zz - seg / 2.0)))
			zz -= seg
	_mm(village, P.box(0.08, 0.1, 2.02), P.mat("6f6a66"), rails)
	var by := H(x, z)
	village.add_child(P.mi(P.box(1.6, 0.6, 0.3), P.mat("c0392b"), Vector3(x, by + 0.4, z + 0.3)))
	# the iron bridge over the north canal, and a fence across the line before it
	var iron := P.mat("4a5550")
	var cz: float = rt.CANAL_N
	for s in [-1.0, 1.0]:
		village.add_child(P.mi(P.box(0.12, 0.9, 6.0), iron, Vector3(x + s * 1.2, rt.TOWN_H + 0.95, cz)))
		for k in 7:
			var strut := P.mi(P.box(0.08, 0.9, 0.08), iron, Vector3(x + s * 1.2, rt.TOWN_H + 0.95, cz - 3.0 + k)); strut.rotation.x = 0.6 if k % 2 else -0.6; village.add_child(strut)
	village.add_child(P.mi(P.box(2.6, 0.3, 6.0), iron, Vector3(x, rt.TOWN_H + 0.35, cz)))
	var f := Props.fence(4.0); f.position = Vector3(x, H(x, cz + rt.CANAL_HALF + 2.0), cz + rt.CANAL_HALF + 2.0); village.add_child(f)

## The warden's river gauge: a tall painted post in the Po with metre bands and numbers, and a plank out to it.
static func _gauge(village: Node3D) -> void:
	for g in _props("river_town_gauge"):
		var post := Node3D.new(); post.position = Vector3(g.x, Heightfield.WATER_Y, g.z); village.add_child(post)
		Props._add(post, P.box(0.32, 4.6, 0.32), P.mat("f4f1ea"), Vector3(0, 1.3, 0))
		for k in 9:
			Props._add(post, P.box(0.34, 0.06, 0.34), P.mat("c0392b" if k % 2 == 0 else "2f3a34"), Vector3(0, k * 0.45, 0))
			for t in 4: Props._add(post, P.box(0.12, 0.02, 0.33), P.mat("2f3a34"), Vector3(-0.08, k * 0.45 + 0.11 * (t + 1), 0), Vector3.ZERO, Vector3.ONE, false)
			if k > 0:
				var lbl := Label3D.new(); lbl.text = str(k); lbl.font = UiTheme.title_font(); lbl.font_size = 40; lbl.pixel_size = 0.004
				lbl.modulate = Color("2f3a34"); lbl.outline_size = 0; lbl.shaded = true; lbl.position = Vector3(0.05, k * 0.45 - 0.2, 0.17)
				post.add_child(lbl)
		Props._add(post, P.box(0.5, 0.12, 0.5), P.mat("2f3a34"), Vector3(0, 3.65, 0))
		var plank := P.mi(P.box(0.6, 0.07, 3.2), P.wood("9a7a5a"), Vector3(g.x + 0.1, H(g.x, g.z - 2.4) + 0.02, g.z - 1.7))
		plank.rotation.x = -0.18; village.add_child(plank)

# ---- the flood's leftovers -----------------------------------------------------------------------------------------

## The piazza still under a few centimetres of brown water, mud on the floodplain, Tullio's ferry half sunk at the
## bank, a car on its roof among the poplars, a fridge against a willow, the sandbag patch in the breach.
static func _flood(village: Node3D, rt) -> void:
	var pond := MeshInstance3D.new(); pond.name = "river_town_pond"
	var cm := CylinderMesh.new(); cm.top_radius = rt.PIAZZA_R + 0.6; cm.bottom_radius = rt.PIAZZA_R + 0.6; cm.height = 0.02; cm.radial_segments = 48
	pond.mesh = cm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.46, 0.47, 0.38, 0.72); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08; wm.metallic = 0.15; wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pond.material_override = wm; pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.position = Vector3(rt.PIAZZA.x, rt.PIAZZA_H + 0.09, rt.PIAZZA.z)
	village.add_child(pond); village.objects["river_town_pond"] = pond
	# mud: grey-brown flats on the floodplain and the gravel where the river overflowed
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var mud: Array = []; var mcols: Array = []
	var tries := 0
	while mud.size() < 30 and tries < 600:
		tries += 1
		var x := rng.randf_range(-50.0, 24.0); var z := rng.randf_range(27.5, 38.0)
		var y := H(x, z)
		if y < -0.12 or y > 0.45 or WorldStatics._near_building(x, z, 1.0) or WorldStatics.dist_to_paths(x, z) < 1.2: continue
		var r := rng.randf_range(0.7, 1.9)
		mud.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(r, 1, r * rng.randf_range(0.35, 0.7))), Vector3(x, y + 0.025, z)))
		mcols.append(Color("8f8460").lerp(Color("7a7050"), rng.randf()))
	_mm(village, P.cyl(1.0, 1.0, 0.02, 14), _tint_mat(0.6), mud, mcols, false)
	# the ferry, half sunk at the bank, its rope still tied to a post
	for f in _props("river_town_ferry"):
		var boat := Node3D.new(); boat.position = Vector3(f.x, Heightfield.WATER_Y - 0.25, f.z); boat.rotation = Vector3(0.25, 0.4, 0.18); village.add_child(boat)
		Props._add(boat, P.rbox(2.0, 0.6, 4.2, 0.2), P.wood("6b5440"), Vector3.ZERO)
		Props._add(boat, P.box(1.8, 0.05, 4.0), P.wood("8a6a50"), Vector3(0, 0.28, 0))
		Props._add(boat, P.cyl(0.03, 0.03, 2.2, 5), P.mat("c9b48a"), Vector3(-1.4, 0.4, -1.4), Vector3(0, 0, 1.2))
		village.add_child(P.mi(P.cyl(0.08, 0.1, 1.2, 6), P.wood("6b5440"), Vector3(f.x - 2.6, H(f.x - 2.6, f.z - 1.4) + 0.5, f.z - 1.4)))
	for c in _props("river_town_car"):
		var car := Node3D.new(); car.position = Vector3(c.x, H(c.x, c.z), c.z); car.rotation = Vector3(0, 0.7, PI - 0.08); car.position.y += 1.3; village.add_child(car)
		Props._add(car, P.rbox(1.6, 0.7, 3.2, 0.2), P.mat("8fa9b8"), Vector3(0, 0.3, 0))
		Props._add(car, P.rbox(1.4, 0.6, 1.8, 0.2), P.mat("8fa9b8"), Vector3(0, 0.85, -0.2))
		Props._add(car, P.box(1.36, 0.42, 1.7), P.mat("3a4a52"), Vector3(0, 0.88, -0.2))
		for w in [[-0.8, -1.0], [0.8, -1.0], [-0.8, 1.0], [0.8, 1.0]]:
			Props._add(car, P.cyl(0.3, 0.3, 0.2, 12), P.mat("2a2a2a"), Vector3(w[0], 0.0, w[1]), Vector3(0, 0, PI / 2))
	var fridge := P.mi(P.rbox(0.7, 1.5, 0.65, 0.08), P.mat("efece4"), Vector3(-28.3, H(-28.3, 31.0) + 0.6, 31.0)); fridge.rotation = Vector3(0.2, 0.5, 0.35); village.add_child(fridge)
	var tub := P.mi(P.rbox(1.5, 0.5, 0.75, 0.22), P.mat("f4f1ea"), Vector3(9.5, H(9.5, 40.4) + 0.15, 40.4)); tub.rotation = Vector3(0.1, 0.4, 0.15); village.add_child(tub)
	# the sandbag patch in the breach: low heaps on either side, the gap still open between them
	var sack := P.fabric("c9b48a")
	var bx: Vector2 = rt.BREACH
	for side in [[bx.x - 0.4, bx.x + 1.4], [bx.y - 1.4, bx.y + 0.4]]:
		for row in 3:
			for k in 3:
				var sx: float = side[0] + (k + 0.5) * (side[1] - side[0]) / 3.0
				var sz: float = rt.LEVEE_Z - 1.2 + row * 1.0
				village.add_child(P.mi(P.rbox(0.62, 0.3, 0.42, 0.12), sack, Vector3(sx, H(sx, sz) + 0.15, sz)))
				village.add_child(P.mi(P.rbox(0.6, 0.28, 0.4, 0.12), sack, Vector3(sx + 0.05, H(sx, sz) + 0.42, sz + 0.05)))
	# a barrier where the levee road ends at the bus stop
	var bar_x: float = rt.LEVEE_WEST - 0.6
	for s in [-1.4, 1.4]: village.add_child(P.mi(P.box(0.15, 1.0, 0.15), P.mat("f4f1ea"), Vector3(bar_x, rt.LEVEE_H + 0.5, rt.LEVEE_Z + s)))
	for k in 6: village.add_child(P.mi(P.box(0.1, 0.12, 0.48), P.mat("c0392b" if k % 2 == 0 else "f4f1ea"), Vector3(bar_x, rt.LEVEE_H + 0.85, rt.LEVEE_Z - 1.2 + k * 0.48)))
	# the bus stop's sign by the turnaround
	var stop := Node3D.new(); stop.position = Vector3(-47.6, H(-47.6, 20.4), 20.4); village.add_child(stop)
	Props._add(stop, P.cyl(0.04, 0.04, 2.4, 6), P.mat("6f7a7a"), Vector3(0, 1.2, 0))
	Props._add(stop, P.cyl(0.32, 0.32, 0.05, 20), P.mat("2f5f9e"), Vector3(0, 2.3, 0), Vector3(PI / 2, 0, 0))
	var bl := Label3D.new(); bl.text = "BUS"; bl.font = UiTheme.title_font(); bl.font_size = 44; bl.pixel_size = 0.004; bl.modulate = Color.WHITE; bl.outline_size = 0
	bl.position = Vector3(0, 2.3, 0.04); stop.add_child(bl)

# ---- everyday details ----------------------------------------------------------------------------------------------

## A bicycle leaning on its stand: two wheels, a frame, a saddle, a basket sometimes.
static func bicycle(color: String, basket: bool = false) -> Node3D:
	var g := Node3D.new()
	var dark := P.mat("2a2a2a"); var frame := P.mat(color); var chrome := P.mat("c9c9c9")
	for z in [-0.52, 0.52]:
		Props._add(g, P.torus(0.33, 0.03, 18), dark, Vector3(0, 0.34, z), Vector3(0, 0, PI / 2))
		Props._add(g, P.cyl(0.02, 0.02, 0.1, 6), chrome, Vector3(0, 0.34, z), Vector3(0, 0, PI / 2))
	Props._add(g, P.cyl(0.022, 0.022, 0.75, 6), frame, Vector3(0, 0.62, 0.0), Vector3(PI / 2 - 0.1, 0, 0))
	Props._add(g, P.cyl(0.022, 0.022, 0.62, 6), frame, Vector3(0, 0.5, 0.18), Vector3(0.75, 0, 0))
	Props._add(g, P.cyl(0.022, 0.022, 0.5, 6), frame, Vector3(0, 0.55, -0.28), Vector3(-0.3, 0, 0))
	Props._add(g, P.cyl(0.02, 0.02, 0.55, 6), frame, Vector3(0, 0.55, 0.47), Vector3(-0.25, 0, 0))
	Props._add(g, P.box(0.12, 0.05, 0.24), dark, Vector3(0, 0.85, -0.32))
	Props._add(g, P.cyl(0.015, 0.015, 0.5, 6), chrome, Vector3(0, 0.86, 0.55), Vector3(0, 0, PI / 2))
	if basket: Props._add(g, P.box(0.32, 0.22, 0.26), P.wood("c49a6c"), Vector3(0, 0.78, 0.7))
	return g

## Bicycles leaning on the walls all over town, because nobody here walks.
static func _bikes(village: Node3D) -> void:
	var cols := ["2f5f9e", "c0392b", "3f5a3a", "e0b04a", "f4f1ea", "6a4a8a", "2f3a34"]
	var spots := [[3.0, -1.9, 0.0, true], [4.0, -1.9, 0.0, false], [9.2, -1.9, 0.0, false], [5.2, -12.0, PI, false], [6.2, -12.0, PI, true], [8.8, -12.0, PI, false],
		[-14.6, -7.0, PI, true], [-17.6, 16.7, 0.0, false], [-23.0, -38.9, 0.0, false], [-24.2, -38.9, 0.0, true], [-27.8, -38.9, 0.0, false], [-2.0, -14.8, PI / 2, false],
		[-11.2, 9.0, 0.0, true], [-39.4, 31.5, PI / 2, false], [46.6, 22.6, -PI / 2, false]]
	for i in spots.size():
		var sp: Array = spots[i]
		var b := bicycle(cols[i % cols.size()], sp[3])
		b.position = Vector3(sp[0], H(sp[0], sp[1]), sp[1]); b.rotation = Vector3(0, sp[2] + PI / 2, 0.22 if i % 2 else -0.22)
		village.add_child(b)

## Reeds round the backwater, along the canals and in the shallows of the Alpine river.
static func _reeds(village: Node3D, rt) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	var xf: Array = []; var cols: Array = []
	var tries := 0
	while xf.size() < 520 and tries < 9000:
		tries += 1
		var x := rng.randf_range(-58.0, 58.0); var z := rng.randf_range(-56.0, 40.0)
		var y := H(x, z)
		if y < -0.32 or y > -0.02: continue   # only right at the water's edge
		if absf(z - rt.ROMAN_Z) < 3.0 or WorldStatics.dist_to_paths(x, z) < 1.4: continue
		if x > 22.0 and x < 40.0 and z > 11.0 and z < 16.0: continue   # leave the pontoon bridge's landings clear
		var s := rng.randf_range(1.6, 2.6)
		xf.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s * 0.8, s, s * 0.8)), Vector3(x, y - 0.02, z)))
		cols.append(Color("a9a46a").lerp(Color("7f9a5a"), rng.randf()))
	_mm(village, Foliage.grass_tuft(), Foliage.plant_material(0.16, 0.0, true), xf, cols, false)

## Harvested maize fields north-west of town: rows of short golden stalks.
static func _stubble(village: Node3D) -> void:
	var xf: Array = []; var cols: Array = []
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for field in [Rect2(-51.5, -50.0, 19.0, 9.5), Rect2(-51.5, -22.0, 9.0, 20.0), Rect2(-51.5, 14.0, 9.0, 3.0)]:
		var x: float = field.position.x
		while x < field.end.x:
			var z: float = field.position.y
			while z < field.end.y:
				if not WorldStatics._near_building(x, z, 0.6) and WorldStatics.dist_to_paths(x, z) > 1.3 and H(x, z) > 0.3:
					var h := rng.randf_range(0.18, 0.42)
					xf.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))).scaled(Vector3(1, h / 0.4, 1)), Vector3(x + rng.randf_range(-0.1, 0.1), H(x, z) + h / 2.0, z)))
					cols.append(Color("c9a65a").lerp(Color("a88a4a"), rng.randf()))
				z += 0.55
			x += 0.8
	_mm(village, P.cyl(0.025, 0.035, 0.4, 5), _tint_mat(), xf, cols, false)

# ---- the horizon ---------------------------------------------------------------------------------------------------

## A jagged ridge facing the map, from x0 to x1 at distance z, peaks from noise; snow on the top part when `snow`.
static func _ridge(village: Node3D, x0: float, x1: float, z: float, h0: float, h1: float, rock: Color, snow: bool, seed: int, smooth: float) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := FastNoiseLite.new(); n.seed = seed; n.frequency = 0.012 / smooth; n.fractal_octaves = 3 if snow else 2
	var steps := 120
	var dir := signf(z)
	var pts: Array = []
	for i in steps + 1:
		var x := lerpf(x0, x1, float(i) / steps)
		var t := 0.5 + 0.5 * n.get_noise_1d(x)
		var y := lerpf(h0, h1, t * t if snow else t)
		pts.append(Vector3(x, y, z + dir * 30.0 * (0.5 + 0.5 * n.get_noise_1d(x + 400.0))))
	var snow_c := Color("f4f6f8"); var shade := rock.darkened(0.15)
	for i in steps:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var a0 := Vector3(a.x, -4.0, a.z - dir * 40.0); var b0 := Vector3(b.x, -4.0, b.z - dir * 40.0)
		var ca := snow_c if snow and a.y > h0 + (h1 - h0) * 0.55 else rock
		var cb := snow_c if snow and b.y > h0 + (h1 - h0) * 0.55 else rock
		for v in [[a0, shade], [a, ca], [b, cb], [a0, shade], [b, cb], [b0, shade]]:
			st.set_color(v[1]); st.add_vertex(v[0])
	st.generate_normals()
	var m := MeshInstance3D.new(); m.mesh = st.commit()
	var mat := _tint_mat(); mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	village.add_child(m)

static func _horizon(village: Node3D, rt) -> void:
	# the Alps up the valley to the north, snow on their tops; a paler farther range behind
	_ridge(village, -700.0, 700.0, -455.0, 30.0, 95.0, Color("8a98a8"), true, 3, 1.0)
	_ridge(village, -640.0, 640.0, -420.0, 8.0, 34.0, Color("7f9282"), false, 9, 1.6)
	# the first Apennine hills beyond the Po's far bank
	_ridge(village, -700.0, 700.0, 300.0, 6.0, 26.0, Color("8fa38a"), false, 17, 2.2)
	# lines of poplars and the bell towers of other villages across the plain
	var rng := RandomNumberGenerator.new(); rng.seed = 33
	var xf: Array = []; var cols: Array = []
	var lines := [[Vector2(-230, -90), Vector2(-70, -90)], [Vector2(-160, -160), Vector2(10, -150)], [Vector2(70, -110), Vector2(230, -100)], [Vector2(90, -200), Vector2(260, -210)],
		[Vector2(-230, 20), Vector2(-80, 25)], [Vector2(80, -30), Vector2(240, -35)], [Vector2(-200, 140), Vector2(-20, 150)], [Vector2(30, 120), Vector2(220, 125)], [Vector2(-120, 210), Vector2(120, 205)]]
	for l in lines:
		var a: Vector2 = l[0]; var b: Vector2 = l[1]
		var cnt := int(a.distance_to(b) / 4.5)
		for k in cnt:
			var p := a.lerp(b, float(k) / cnt) + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
			var y: float = 0.45 if p.y > 80.0 else (rt.EAST_H if p.x > 62.0 and p.y < 40.0 else rt.TOWN_H) - 0.03
			var s := rng.randf_range(0.9, 1.25)
			xf.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(p.x, y, p.y)))
			cols.append(Color(LEAVES["column"][rng.randi() % 4]))
	_mm(village, canopy("column"), Foliage.plant_material(0.02, 1.0), xf, cols, false)
	var brick := P.plaster("b0644a")
	for t in [[Vector2(160, -70), 14.0], [Vector2(-190, -40), 12.0], [Vector2(-60, 175), 13.0], [Vector2(110, 165), 11.0], [Vector2(-120, -200), 12.0]]:
		var p: Vector2 = t[0]; var th: float = t[1]
		var y: float = 0.45 if p.y > 80.0 else rt.TOWN_H
		village.add_child(P.mi(P.box(2.0, th, 2.0), brick, Vector3(p.x, y + th / 2.0, p.y), false))
		var cap := P.mi(P.cone(1.7, 2.4, 4), Props.roof_material("b5653a"), Vector3(p.x, y + th + 1.2, p.y), false); cap.rotation.y = PI / 4; village.add_child(cap)
		for k in 4:
			var r := P.mi(P.box(rng.randf_range(5.0, 9.0), 3.0, rng.randf_range(4.0, 6.0)), P.plaster(["e8c77a", "d9935a", "efe2c4"][k % 3]), Vector3(p.x + rng.randf_range(-12, 12), y + 1.5, p.y + rng.randf_range(-8, 8)), false)
			village.add_child(r)
