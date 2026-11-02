class_name Village
extends Node3D
## Builds Hearthglow Village from the layout data: terrain, water, buildings, decor, resource nodes, features.
const P := preload("res://scripts/world/palette.gd")

var objects: Dictionary = {}
var node_visuals: Dictionary = {}
var lamps: Array = []
var terrain: MeshInstance3D
var water: MeshInstance3D

func build(decor: Dictionary) -> void:
	terrain = TerrainBuilder.build_terrain(); add_child(terrain)
	water = TerrainBuilder.build_water(); add_child(water)
	var H := func(x: float, z: float) -> float: return Heightfield.height(x, z)
	for b in Data.layout.buildings:
		var o: Node3D
		match b.kind:
			"workshop": o = Props.workshop(b)
			"castle": o = Props.castle(b)
			"caravan": o = Props.caravan(b)
			_: o = Props.cottage(b)
		o.position = Vector3(b.x, (H.call(b.x, b.z) - 0.05) if b.kind == "castle" else maxf(0.0, H.call(b.x, b.z)), b.z)
		o.name = b.id; add_child(o); objects[b.id] = o
	var f := Props.fountain(); var F: Dictionary = Data.layout.fountain; f.position = Vector3(F.x, 0, F.z); add_child(f); objects["fountain"] = f
	for c in Data.layout.harbor_cliffs:
		var w: float = c.maxX - c.minX
		if w > 60: continue
	for seg in [[-48.0, 2.5], [7.5, 50.0]]:
		var cl := Props.cliff(seg[1] - seg[0]); cl.position = Vector3((seg[0] + seg[1]) / 2.0, -0.2, 34.8); add_child(cl)
	var G: Dictionary = Data.layout.harbor_gate
	var gate := Props.gate(); gate.position = Vector3((G.minX + G.maxX) / 2.0, H.call(5, 34.7), 34.7); add_child(gate); objects["harborGate"] = gate
	var stall := Props.market_stall(); stall.position = Vector3(-2, H.call(-2, 39), 39); stall.rotation.y = 0.2; add_child(stall)
	var dock: Dictionary = Data.zone("dock")
	for s in dock.fixedSupports:
		add_child(P.mi(P.cyl(0.2, 0.24, 2.4, 8), P.mat("8a6a50"), Vector3(s[0] + 0.5, -1.0, s[1] + 0.5)))
		add_child(P.mi(P.cyl(0.26, 0.26, 0.08, 8), P.mat("6a4a30"), Vector3(s[0] + 0.5, 0.02, s[1] + 0.5)))
	add_child(P.mi(P.cyl(0.18, 0.22, 2.6, 8), P.mat("8a6a50"), Vector3(4.3, -0.6, 50.4)))
	for bp in [[-1.6, -17.2, 0.3], [1.8, -19.6, -0.4], [-0.4, -20.4, 0.2]]:
		var p := Props.broken_post(); p.position = Vector3(bp[0], -0.2, bp[1]); p.rotation.z = bp[2]; add_child(p)
	var plank := P.mi(P.box(0.9, 0.1, 1.6), P.mat("9a7a5a"), Vector3(1.2, -0.36, -16.6)); plank.rotation = Vector3(0.1, 0.7, 0.15); add_child(plank)
	for l in [[-6, -3], [6, -3], [-6, 7.5], [6.8, 7.2], [-20, 5.2], [-30, 6.6], [2, -12.5], [12.6, 1.2], [4.6, 20.6], [20, 6.8], [7.4, 31.5]]:
		var lp := Props.lamp_post(); lp.position = Vector3(l[0], H.call(l[0], l[1]), l[1]); add_child(lp); lamps.append(lp.get_node("bulb"))
	for fc in [[3.4, -12.2, 4, 0.0], [3.4, -8.0, 4, 0.0], [1.4, -10.1, 4, PI / 2], [-40, 2.5, 3, 0.0], [-40, 7.6, 3, 0.0]]:
		var fe := Props.fence(fc[2]); fe.position = Vector3(fc[0], H.call(fc[0], fc[1]), fc[1]); fe.rotation.y = fc[3]; add_child(fe)
	for bd in [[4.4, -9.4], [6.6, -9.4], [4.4, -11], [6.6, -11]]: add_child(P.mi(P.box(1.6, 0.16, 1.1), P.mat("9a6a45"), Vector3(bd[0], 0.08, bd[1])))
	var pier := P.mi(P.box(7, 0.15, 2.2), P.mat("c49a6c"), Vector3(-48.5, 0.05, 5)); add_child(pier)
	_build_decor(decor)
	_build_nodes()
	_build_features()

func _multimesh(mesh: Mesh, material: Material, items: Array, place: Callable, shadow: bool = true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var r: Array = place.call(items[i])   # [Transform3D, Color]
		mm.set_instance_transform(i, r[0])
		mm.set_instance_color(i, r[1])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)

func _tinted() -> StandardMaterial3D:
	var m := P.unique_mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m

func _build_decor(decor: Dictionary) -> void:
	var H := func(x: float, z: float) -> float: return Heightfield.height(x, z)
	var xf := func(pos: Vector3, s: Vector3, ry: float = 0.0, rx: float = 0.0) -> Transform3D:
		return Transform3D(Basis.from_euler(Vector3(rx, ry, 0)).scaled(s), pos)
	var round: Array = []; var pine: Array = []
	for t in decor.trees: (pine if t.kind == "pine" else round).append(t)
	var tint := _tinted()
	_multimesh(P.cyl(0.16, 0.24, 1.3, 7), tint, decor.trees, func(t): return [xf.call(Vector3(t.x, H.call(t.x, t.z) + 0.65 * t.s, t.z), Vector3.ONE * t.s), P.TRUNK])
	var leaves := [Color("5cb85c"), Color("6cc65a"), Color("4fae63"), Color("7ccc5a"), Color("5fbf7a")]
	_multimesh(P.sphere(1.0, 9, 6), tint, round, func(t): return [xf.call(Vector3(t.x, H.call(t.x, t.z) + 1.9 * t.s, t.z), Vector3(1.05, 0.95, 1.05) * t.s, t.hue * 6.0), leaves[int(t.hue * leaves.size()) % leaves.size()]])
	_multimesh(P.sphere(0.7, 9, 6), tint, round, func(t): return [xf.call(Vector3(t.x + 0.3 * t.s, H.call(t.x, t.z) + 2.55 * t.s, t.z - 0.1), Vector3.ONE * t.s), leaves[(int(t.hue * 7) + 1) % leaves.size()]])
	for c in [[1.2, 1.0, 1.3], [1.9, 0.78, 1.1], [2.5, 0.52, 0.9]]:
		_multimesh(P.cone(c[1], c[2], 8), tint, pine, func(t): return [xf.call(Vector3(t.x, H.call(t.x, t.z) + c[0] * t.s, t.z), Vector3.ONE * t.s), P.PINE])
	var bush_cols := [Color("69bf5f"), Color("5aa65a"), Color("7dcf6a")]
	_multimesh(P.sphere(0.5, 8, 6), tint, decor.bushes, func(b): return [xf.call(Vector3(b.x, H.call(b.x, b.z) + 0.25 * b.s, b.z), Vector3(1.2, 0.8, 1.0) * b.s), bush_cols[int(b.hue * 3) % 3]])
	_multimesh(P.sphere(0.09, 5, 3), tint, decor.flowers, func(f): return [xf.call(Vector3(f.x, H.call(f.x, f.z) + 0.26 * f.s, f.z), Vector3.ONE * f.s), P.FLOWERS[int(f.c)]], false)
	_multimesh(P.cyl(0.015, 0.015, 0.26, 3), tint, decor.flowers, func(f): return [xf.call(Vector3(f.x, H.call(f.x, f.z) + 0.13 * f.s, f.z), Vector3.ONE * f.s), Color("4f9e45")], false)
	_multimesh(P.cone(0.07, 0.32, 3), tint, decor.grass, func(g): return [xf.call(Vector3(g.x, H.call(g.x, g.z) + 0.14 * g.s, g.z), Vector3.ONE * g.s, g.r, (g.r - 1.5) * 0.2), Color("6fbf4f")], false)

func _build_nodes() -> void:
	for n in Data.layout.nodes:
		var o: Node3D
		match n.kind:
			"chop": o = Props.round_tree(1.05, fmod(n.x * 7.3, 1.0) if n.x > 0 else fmod(-n.x * 7.3, 1.0))
			"mine": o = Props.rock(n.get("rich", false))
			"clay": o = Props.clay_mound()
			"fish": o = Props.fishing_spot()
			"flowers": o = Props.flower_patch()
			"shake": o = Props.oak()
			"fruit": o = Props.round_tree(0.9, 0.7); Props.add_fruit(o).visible = false
			"dig": o = Props.dig_spot()
			"chest": o = Props.chest()
			"fragment": o = Props.fragment()
			_: o = Node3D.new()
		var y := maxf(Heightfield.height(n.x, n.z), -0.2) if n.kind == "fish" else Heightfield.height(n.x, n.z)
		o.position = Vector3(n.x, y, n.z)
		if n.kind == "fragment": o.position.y += 1.0
		if n.kind == "chest": o.rotation.y = atan2(-n.x, -n.z)
		if n.has("facing"): o.rotation.y = n.facing
		o.name = n.id; add_child(o); objects[n.id] = o; node_visuals[n.id] = o
		if n.kind == "chop":
			var st := P.mi(P.cyl(0.24, 0.28, 0.3, 8), P.mat(P.TRUNK), Vector3(n.x, y + 0.15, n.z)); st.visible = false; add_child(st)
			o.set_meta("stump", st)

func _build_features() -> void:
	for f in Data.layout.features:
		var o: Node3D
		match f.kind:
			"sign": o = Props.sign_post()
			"board": o = Props.notice_board()
			"wardrobe": o = Props.wardrobe()
			"boat": o = Props.boat(); o.visible = false
			_: o = Node3D.new()
		o.position = Vector3(f.x, -0.45 if f.kind == "boat" else Heightfield.height(f.x, f.z), f.z)
		if f.id == "welcomeSign": o.rotation.y = PI / 2
		o.name = f.id; add_child(o); objects[f.id] = o

func update_world(dt: float, t: float, flags: Dictionary) -> void:
	Props.animate_fountain(objects.fountain, t, flags.get("fountainFlowing", false))
	for n in Data.layout.nodes:
		if n.kind == "fragment":
			var o: Node3D = node_visuals[n.id]
			if o.visible:
				o.position.y = Heightfield.height(n.x, n.z) + 1.0 + sin(t * 2.0 + n.x) * 0.15
				o.rotation.y = t * 1.5
	var open := 1.0 if flags.get("harborOpen", false) else 0.0
	for d in objects.harborGate.get_node("doors").get_children():
		d.rotation.y = lerpf(d.rotation.y, -float(d.get_meta("side")) * open * 1.6, 1.0 - exp(-dt * 2.0))
	objects.harborGate.get_node("seal").visible = not flags.get("harborOpen", false)
	var boat: Node3D = objects.boat
	boat.visible = flags.get("boatReady", false)
	if boat.visible: boat.position.y = -0.45 + sin(t * 1.3) * 0.06; boat.rotation.z = sin(t * 0.9) * 0.03
	var ws: Node3D = objects.workshop
	ws.get_node("clutter").visible = not flags.get("workshopDone", false)
	if flags.get("workshopDone", false): ws.get_node("signGear").rotation.x = t * 1.5
	objects.caravan.get_node("cog").rotation.y = t * 0.8
	for l in lamps: (l.material_override as StandardMaterial3D).emission_energy_multiplier = 2.5 if flags.get("night", false) else 0.15
