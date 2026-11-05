extends RefCounted
## Casalrana's scenery (stage 2), added after everything else is built (rice_village.gd's dress). Bare winter trees:
## poplars in the plantation and along the ditches (the plantation's gathering spots become poplars too), pollarded
## willows and alders round the spring pool, robinia on the railway bed, old mulberries along the field edges. Straw
## bales, the station's payphone, the telegraph line and the overhead wires, the farmstead's gate arch, the collapsed
## sluice, the bus stop. Past the edge, the plain runs on: flooded paddies on a grid of banks, rows of poplars, the
## railway on its embankment, and distant farmsteads and bell towers fading into the haze.
##
## Solid scenery comes from the layout's props (kinds rice_village_*: the shared code makes them solid and leaves their
## look to this file). Everything past the edge is out of reach, so it's looks only.
const P := preload("res://scripts/world/palette.gd")
const Tex := preload("res://scripts/locations/rice_village/textures.gd")
const Buildings := preload("res://scripts/locations/rice_village/buildings.gd")
const Trains := preload("res://scripts/locations/rice_village/trains.gd")
const Life := preload("res://scripts/locations/rice_village/village_life.gd")

const RAIL_Y := 0.62
const RAIL_Z := -47.0
const WIRE_Y := 5.66           # the contact wire, where the pantographs touch it
const BANK := Color("8f8a64")

static func dress(village: Node3D) -> void:
	var game = village.get_parent()
	var trees := TreeBatch.new()
	_bus_stop(village)
	_reskin_poplars(village)
	var poles: Array = []
	for pr in Data.layout.get("props", []):
		var k := String(pr.kind)
		var pos := Vector3(float(pr.x), Heightfield.height(pr.x, pr.z), float(pr.z))
		var s := float(pr.get("s", 1.0)); var seed := int(absf(pr.x * 13.0 + pr.z * 7.0))
		match k:
			"rice_village_poplar": trees.poplar(pos, s, seed, bool(pr.get("narrow", false)))
			"rice_village_willow": trees.willow(pos, s, seed)
			"rice_village_alder": trees.alder(pos, s, seed)
			"rice_village_robinia": trees.robinia(pos, s, seed)
			"rice_village_mulberry": trees.mulberry(pos, s, seed)
			"rice_village_bale": village.add_child(_bale(pos, float(pr.get("r", 0.0))))
			"rice_village_payphone": village.add_child(_payphone(pos, float(pr.get("r", 0.0))))
			"rice_village_pole": poles.append(pos)
	_telegraph(village, poles)
	_overhead_line(village)
	_gate_arch(village)
	_sluice_ruins(village)
	_beyond(village, trees)
	trees.build(village)
	var tr := Trains.new(); tr.name = "rice_village_trains"
	village.add_child(tr)
	tr.setup(game, village)
	_straw(village)
	# your flat upstairs: its roof and chimneys fade while you're in it (the station built them)
	var st: Node3D = village.objects.get("rice_village_station"); var fl: Node3D = village.objects.get("rice_village_flat")
	if st and fl and st.has_meta("upstairs_fade"): fl.set_meta("fade_parts", st.get_meta("upstairs_fade"))
	var life := Life.new(); life.name = "rice_village_life"
	village.add_child(life)
	life.setup(game, village)

## Loose straw on the stubble (gathering spots of kind "flowers" that give straw): a tuft and a little sheaf instead
## of the shared flower patch.
static func _straw(village: Node3D) -> void:
	var gold := P.mat("d9c27a"); var pale := P.mat("e6d49a")
	for n in Data.layout.nodes:
		if n.kind != "flowers" or not n.get("gives", {}).has("rice_village_straw"): continue
		var o: Node3D = village.node_visuals.get(n.id)
		if o == null: continue
		for c in o.get_children(): (c as Node3D).visible = false
		var seed := int(absf(float(n.x) * 7.0 + float(n.z) * 3.0))
		for k in 7:
			var a := k * 0.9 + seed * 0.3
			var r := 0.15 + (k % 3) * 0.12
			_add(o, P.cyl(0.015, 0.05, 0.32, 4), pale if k % 2 else gold, Vector3(cos(a) * r, 0.12, sin(a) * r), Vector3(cos(a) * 0.9, 0, sin(a) * 0.9))
		var sheaf := _add(o, P.cyl(0.12, 0.16, 0.42, 8), gold, Vector3(0.1, 0.16, -0.05), Vector3(0, 0, 1.45))
		_add(sheaf, P.cyl(0.13, 0.13, 0.05, 8), P.mat("b8964a"), Vector3.ZERO)

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadow: bool = true) -> MeshInstance3D:
	var m := P.mi(mesh, mat, pos, shadow)
	m.rotation = rot; m.scale = scl
	parent.add_child(m)
	return m

static func _xf(pos: Vector3, scl: Vector3, rot: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)

## The bus stop's pole and round blue sign (the shared departure point is a boat, which stays hidden here).
static func _bus_stop(village: Node3D) -> void:
	for f in Data.layout.features:
		if f.kind != "boat": continue
		var stop := Node3D.new(); stop.name = "rice_village_busStopSign"
		_add(stop, P.cyl(0.05, 0.05, 2.4, 8), P.mat("8b9097"), Vector3(0, 1.2, 0))
		_add(stop, P.cyl(0.32, 0.32, 0.05, 20), P.mat("2f6db5"), Vector3(0, 2.3, 0), Vector3(PI / 2, 0, 0))
		_add(stop, P.box(0.5, 0.08, 0.06), P.mat("f4f1ea"), Vector3(0, 2.3, 0.04))
		_add(stop, P.box(0.5, 0.36, 0.03), P.mat("f4f1ea"), Vector3(0, 1.75, 0.02))
		stop.position = Vector3(f.x, Heightfield.height(f.x, f.z), f.z)
		village.add_child(stop)

## The plantation's gathering spots: the shared round tree goes, a bare poplar takes its place (the forester's ribbon
## stays, a little bigger for the thicker trunk).
static func _reskin_poplars(village: Node3D) -> void:
	for n in Data.layout.nodes:
		if n.kind != "chop" or not String(n.id).begins_with("rice_village_"): continue
		var o: Node3D = village.node_visuals.get(n.id)
		if o == null: continue
		for c in o.get_children():
			if c.name == "ribbon": c.scale = Vector3(1.35, 1.0, 1.35); continue
			o.remove_child(c); c.queue_free()
		o.add_child(poplar_node(1.0 / o.scale.x, int(absf(n.x * 13.0 + n.z * 7.0))))

## One bare poplar as its own node (for a gathering spot, which shakes and falls on its own).
static func poplar_node(s: float, seed: int) -> Node3D:
	var g := Node3D.new()
	var bark := P.wood("bdb6a8"); var twig := Tex.twigs(Color("6a625a"))
	var h := (8.5 + float(seed % 5) * 0.5) * s
	_add(g, P.cyl(0.13 * s, 0.3 * s, h * 0.7, 9), bark, Vector3(0, h * 0.35, 0))
	for k in 5:
		var a := float(k) * TAU / 5.0 + seed * 0.37
		_add(g, P.cyl(0.03 * s, 0.08 * s, 2.6 * s, 6), bark, Vector3(cos(a) * 0.5 * s, h * 0.62 + k * 0.25 * s, sin(a) * 0.5 * s), Vector3(sin(a) * 0.55, 0, -cos(a) * 0.55))
	_add(g, P.sphere(1.0, 10, 8), twig, Vector3(0, h * 0.82, 0), Vector3(0, seed * 0.5, 0), Vector3(2.3, 3.3, 2.3) * s, false)
	if seed % 3 == 0: _add(g, P.sphere(0.36 * s, 8, 6), P.mat("78874a"), Vector3(0.6 * s, h * 0.86, 0.3 * s))
	return g

## Trees in bulk: each part (trunks, branches, twig crowns, willow shoots, mistletoe) is one MultiMesh.
class TreeBatch:
	const P := preload("res://scripts/world/palette.gd")
	const Tex := preload("res://scripts/locations/rice_village/textures.gd")
	var parts: Dictionary = {}   # part name -> [mesh, material, transforms, shadow]

	static func _xf(pos: Vector3, scl: Vector3, rot: Vector3 = Vector3.ZERO) -> Transform3D:
		return Transform3D(Basis.from_euler(rot).scaled(scl), pos)

	func _put(name: String, mesh: Mesh, mat: Material, xf: Transform3D, shadow: bool = true) -> void:
		if not parts.has(name): parts[name] = [mesh, mat, [], shadow]
		parts[name][2].append(xf)

	func poplar(pos: Vector3, s: float, seed: int, narrow: bool = false) -> void:
		var h := (9.0 + float(seed % 7) * 0.55) * s
		_put("trunk", P.cyl(0.4, 1.0, 1.0, 8), P.wood("a8a092" if narrow else "bdb6a8"), _xf(pos + Vector3(0, h * 0.36, 0), Vector3(0.28 * s, h * 0.72, 0.28 * s)))
		var crown := Vector3(1.4, 4.3, 1.4) if narrow else Vector3(2.3, 3.3, 2.3)
		_put("crown", P.sphere(1.0, 10, 8), Tex.twigs(Color("6a625a")), _xf(pos + Vector3(0, h * (0.78 if narrow else 0.82), 0), crown * s, Vector3(0, seed * 0.5, 0)), false)
		for k in (3 if narrow else 5):
			var a := float(k) * TAU / 5.0 + seed * 0.37
			var tilt := 0.3 if narrow else 0.55
			_put("branch", P.cyl(0.3, 1.0, 1.0, 5), P.wood("b0a899"), _xf(pos + Vector3(cos(a) * 0.5 * s, h * 0.62 + k * 0.25 * s, sin(a) * 0.5 * s), Vector3(0.08 * s, 2.6 * s, 0.08 * s), Vector3(sin(a) * tilt, 0, -cos(a) * tilt)))
		if seed % 3 == 0: _put("mistletoe", P.sphere(1.0, 8, 6), P.mat("78874a"), _xf(pos + Vector3(0.6 * s, h * 0.86, 0.3 * s), Vector3.ONE * 0.36 * s))

	## A pollarded willow: a short thick trunk with a knob of straight yellow-orange shoots, as they stand all winter.
	func willow(pos: Vector3, s: float, seed: int) -> void:
		var h := 2.0 * s
		_put("w_trunk", P.cyl(0.32, 0.4, 1.0, 9), P.wood("7d6c58"), _xf(pos + Vector3(0, h / 2.0, 0), Vector3(s, h, s)))
		_put("w_knob", P.sphere(0.5, 9, 7), P.wood("6d5d4a"), _xf(pos + Vector3(0, h, 0), Vector3(1.1, 0.8, 1.1) * s))
		for k in 30:
			var a := float(k) * 2.4 + seed
			var lean := 0.25 + 0.35 * fmod(k * 0.618, 1.0)
			var length := (1.5 + 0.9 * fmod(k * 0.37 + seed * 0.1, 1.0)) * s
			var dir := Vector3(sin(lean) * cos(a), cos(lean), sin(lean) * sin(a))
			_put("w_shoot", P.cyl(0.5, 1.0, 1.0, 6), P.wood("d39a3c"), _xf(pos + Vector3(0, h, 0) + dir * length * 0.5, Vector3(0.022 * s, length, 0.022 * s), Vector3(sin(a) * lean, 0, -cos(a) * lean)), false)

	func alder(pos: Vector3, s: float, seed: int) -> void:
		var h := (5.0 + float(seed % 3) * 0.6) * s
		_put("a_trunk", P.cyl(0.4, 1.0, 1.0, 8), P.wood("5a5048"), _xf(pos + Vector3(0, h * 0.35, 0), Vector3(0.2 * s, h * 0.7, 0.2 * s)))
		_put("a_crown", P.sphere(1.0, 10, 8), Tex.twigs(Color("4a3d3d")), _xf(pos + Vector3(0, h * 0.75, 0), Vector3(1.9, 2.5, 1.9) * s, Vector3(0, seed, 0)), false)

	## Robinia: a thorny scrub of a few leaning stems, all twigs in winter.
	func robinia(pos: Vector3, s: float, seed: int) -> void:
		for k in 3:
			var a := float(k) * 2.1 + seed
			_put("r_stem", P.cyl(0.4, 1.0, 1.0, 5), P.wood("4f4741"), _xf(pos + Vector3(cos(a) * 0.25, 1.1 * s, sin(a) * 0.25), Vector3(0.07 * s, 2.3 * s, 0.07 * s), Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)))
		_put("r_crown", P.sphere(1.0, 9, 7), Tex.twigs(Color("3f3833")), _xf(pos + Vector3(0, 2.4 * s, 0), Vector3(1.4, 1.1, 1.4) * s, Vector3(0, seed, 0)), false)

	## An old pollarded mulberry from the days of silkworms: thick and knobbly, with a small twiggy head.
	func mulberry(pos: Vector3, s: float, seed: int) -> void:
		var h := 2.4 * s
		_put("m_trunk", P.cyl(0.3, 0.38, 1.0, 9), P.wood("6d5d4a"), _xf(pos + Vector3(0, h / 2.0, 0), Vector3(s, h, s), Vector3(0.06, seed, 0.04)))
		for k in 6:
			var a := float(k) * TAU / 6.0 + seed
			_put("m_arm", P.cyl(0.5, 1.0, 1.0, 5), P.wood("6d5d4a"), _xf(pos + Vector3(cos(a) * 0.35 * s, h + 0.4 * s, sin(a) * 0.35 * s), Vector3(0.09 * s, 1.1 * s, 0.09 * s), Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7)))
		_put("m_crown", P.sphere(1.0, 9, 7), Tex.twigs(Color("5a4c40")), _xf(pos + Vector3(0, h + 1.1 * s, 0), Vector3(1.6, 1.1, 1.6) * s, Vector3(0, seed, 0)), false)

	func build(village: Node3D) -> void:
		for name in parts:
			var spec: Array = parts[name]
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = spec[0]; mm.instance_count = spec[2].size()
			for i in spec[2].size(): mm.set_instance_transform(i, spec[2][i])
			var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = spec[1]; mi.name = "rice_village_" + name
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if spec[3] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			village.add_child(mi)

# ---- Small things -----------------------------------------------------------------------------------------------
## A round straw bale lying on the stubble.
static func _bale(pos: Vector3, r: float) -> Node3D:
	var g := Node3D.new(); g.position = pos; g.rotation.y = r
	var straw := P.fabric("d9c27a")
	_add(g, P.cyl(0.75, 0.75, 1.25, 16), straw, Vector3(0, 0.72, 0), Vector3(0, 0, PI / 2))
	for x in [-0.63, 0.63]:
		_add(g, P.cyl(0.7, 0.7, 0.02, 16), P.fabric("c4a964"), Vector3(x, 0.72, 0), Vector3(0, 0, PI / 2))
		_add(g, P.torus(0.4, 0.04, 14), P.fabric("b89a58"), Vector3(x * 1.02, 0.72, 0), Vector3(0, 0, PI / 2))
	for x in [-0.3, 0.3]: _add(g, P.torus(0.76, 0.02, 18), P.mat("e9e2d0"), Vector3(x, 0.72, 0), Vector3(0, 0, PI / 2))
	return g

## The payphone on the station forecourt: a hood on a post, the phone that takes tokens and cards.
static func _payphone(pos: Vector3, r: float) -> Node3D:
	var g := Node3D.new(); g.position = pos; g.rotation.y = r
	_add(g, P.cyl(0.06, 0.07, 1.9, 8), P.mat("8b9097"), Vector3(0, 0.95, 0))
	_add(g, P.rbox(0.75, 0.9, 0.5, 0.06), P.mat("9aa0a6"), Vector3(0, 1.8, 0.2))
	_add(g, P.rbox(0.38, 0.5, 0.14, 0.03), P.mat("4a4f55"), Vector3(0, 1.6, 0.35))
	_add(g, P.rbox(0.1, 0.32, 0.08, 0.03), P.mat("2b2826"), Vector3(-0.12, 1.62, 0.44))
	_add(g, P.box(0.75, 0.14, 0.04), P.mat("2f6db5"), Vector3(0, 2.2, 0.43))
	return g

## The telegraph line along the railway: wooden poles with glass insulators and two sagging wires, out past the edge.
static func _telegraph(village: Node3D, poles: Array) -> void:
	var all: Array = poles.duplicate()
	for x in range(-300, -56, 30): all.append(Vector3(x, RAIL_Y, -50.6))
	for x in range(60, 301, 30): all.append(Vector3(x, RAIL_Y, -50.6))
	all.sort_custom(func(a, b): return a.x < b.x)
	var wood := P.wood("6b5a48"); var glass := P.mat("cfe3d6")
	for i in all.size():
		var p: Vector3 = all[i]
		var lean := 0.04 * sin(p.x * 0.7)
		var pole := Node3D.new(); pole.position = p; pole.rotation.z = lean; village.add_child(pole)
		_add(pole, P.cyl(0.08, 0.12, 7.0, 7), wood, Vector3(0, 3.5, 0))
		_add(pole, P.box(0.08, 0.1, 1.3), wood, Vector3(0, 6.6, 0))
		for z in [-0.5, 0.5]: _add(pole, P.sphere(0.07, 6, 5), glass, Vector3(0, 6.72, z), Vector3.ZERO, Vector3.ONE, false)
		if i == 0: continue
		var a: Vector3 = all[i - 1]
		for z in [-0.5, 0.5]:
			var p0 := a + Vector3(0, 6.72, z); var p1 := p + Vector3(0, 6.72, z)
			var mid := (p0 + p1) / 2.0 - Vector3(0, 0.35, 0)
			_wire(village, p0, mid, 0.012); _wire(village, mid, p1, 0.012)

static func _wire(parent: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var m := P.mi(P.box(d.length(), r * 2.0, r * 2.0), P.mat("3a3632"), (a + b) / 2.0, false)
	m.rotation = Vector3(0, -atan2(d.z, d.x), atan2(d.y, Vector2(d.x, d.z).length()))
	parent.add_child(m)

## The overhead line: lattice masts on the north side of the line with arms over both tracks, and the contact wires
## the trains' pantographs touch.
static func _overhead_line(village: Node3D) -> void:
	var steel := P.mat("7d8288")
	for x in range(-300, 301, 30):
		var mast := Node3D.new(); mast.position = Vector3(x, RAIL_Y, RAIL_Z - 2.15); village.add_child(mast)
		_add(mast, P.box(0.28, 6.6, 0.28), steel, Vector3(0, 3.3, 0))
		_add(mast, P.box(0.1, 0.12, 4.6), steel, Vector3(0, 6.3, 2.2))
		for z in [1.15, 3.15]: _add(mast, P.box(0.04, 0.6, 0.04), steel, Vector3(0, 5.95, z))
	for z in [RAIL_Z - 1.0, RAIL_Z + 1.0]:
		_add(village, P.box(600.0, 0.03, 0.03), P.mat("3a3632"), Vector3(0, WIRE_Y, z), Vector3.ZERO, Vector3.ONE, false)
		_add(village, P.box(600.0, 0.025, 0.025), P.mat("3a3632"), Vector3(0, WIRE_Y + 0.6, z), Vector3.ZERO, Vector3.ONE, false)

## The farmstead's gateway: an arch of brick over the gap in the west wall, with a little tiled roof.
static func _gate_arch(village: Node3D) -> void:
	var g := Node3D.new(); g.position = Vector3(12.7, Heightfield.height(12.7, -6.0), -6.0); village.add_child(g)
	var brick := Tex.brick(Color("b8664c"))
	_add(g, P.box(0.6, 0.7, 5.0), brick, Vector3(0, 3.0, 0))
	_add(g, P.box(0.62, 0.5, 3.6), brick, Vector3(0, 2.55, 0), Vector3(PI, 0, 0), Vector3(1, 1, 1))
	var roof := Props.roof_material("a5503a")
	for s in [-1, 1]: _add(g, P.box(1.0, 0.08, 5.4), roof, Vector3(s * 0.32, 3.48, 0), Vector3(0, 0, -s * 0.5))
	for z in [-2.3, 2.3]: _add(g, P.box(0.75, 3.6, 0.75), brick, Vector3(0, 1.8, z))

## The collapsed sluice: two broken brick piers on the canal banks, the old gate's planks fallen in the mud and a
## rusty winch. (Water for the Winter rebuilds it in stage 3.)
static func _sluice_ruins(village: Node3D) -> void:
	var g := Node3D.new(); g.name = "rice_village_sluiceRuins"; g.position = Vector3(-40.0, 0.0, -28.0); village.add_child(g)
	var brick := Tex.brick(Color("a85c46")); var rust := P.mat("8a4e2e")
	for x in [-2.6, 2.6]:
		var y := Heightfield.height(-40.0 + x, -28.0)
		_add(g, P.box(0.8, 1.6 if x < 0 else 1.1, 0.9), brick, Vector3(x, y + (0.8 if x < 0 else 0.55), 0))
		_add(g, P.box(0.5, 0.4, 0.5), brick, Vector3(x + 0.1, y + (1.75 if x < 0 else 1.25), 0.15), Vector3(0.3, 0.4, 0.5))
	for k in 4:
		_add(g, P.box(2.2, 0.06, 0.3), P.wood("6b5440"), Vector3(-0.6 + k * 0.5, Heightfield.height(-40.0, -28.0) + 0.05, -0.6 + k * 0.4), Vector3(0.1 * k, 0.6 + k * 0.4, 0.05))
	_add(g, P.cyl(0.3, 0.3, 0.12, 12), rust, Vector3(-2.6, Heightfield.height(-42.6, -28.0) + 1.75, 0.5), Vector3(PI / 2, 0, 0))
	_add(g, P.box(0.06, 1.6, 0.06), rust, Vector3(-2.2, Heightfield.height(-42.2, -28.0) + 0.6, 0.0), Vector3(0, 0, 0.9))

# ---- Past the edge ----------------------------------------------------------------------------------------------
## The plain running on: banks on a grid across the flooded paddies, rows of poplars along some of them, the railway
## on its embankment with the telegraph and overhead lines, and distant farmsteads and bell towers.
static func _beyond(village: Node3D, trees: TreeBatch) -> void:
	var banks: Array = []
	var step := 22.0; var reach := 330.0; var inner := 56.5
	var lines: Array = []
	var v := 2.0 - step * 15.0
	while v <= reach: lines.append(v); v += step
	for c in lines:
		if absf(c) < inner:
			for seg in [[-reach, -inner], [inner, reach]]:
				banks.append(_xf(Vector3((seg[0] + seg[1]) / 2.0, -0.4, c), Vector3(seg[1] - seg[0], 0.32, 1.5)))
				banks.append(_xf(Vector3(c, -0.4, (seg[0] + seg[1]) / 2.0), Vector3(1.5, 0.32, seg[1] - seg[0])))
		else:
			banks.append(_xf(Vector3(0, -0.4, c), Vector3(reach * 2.0, 0.32, 1.5)))
			banks.append(_xf(Vector3(c, -0.4, 0), Vector3(1.5, 0.32, reach * 2.0)))
	_multimesh(village, P.box(1, 1, 1), P.mat(BANK), banks, false)
	# rows of poplars along some of the far banks
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for c in lines:
		if absf(c) < inner or rng.randf() > 0.45: continue
		var along_x := rng.randf() < 0.5
		var from := -reach * 0.7; var to := reach * 0.7
		var p := from
		while p < to:
			var q := Vector3(p, -0.25, c + 1.4) if along_x else Vector3(c + 1.4, -0.25, p)
			if maxf(absf(q.x), absf(q.z)) > inner + 6.0 and Vector2(q.x, q.z).length() < reach * 0.8: trees.poplar(q, rng.randf_range(0.9, 1.15), rng.randi(), true)
			p += rng.randf_range(6.0, 8.0)
	# the railway carries on along its embankment
	for side in [-1.0, 1.0]:
		var length := 260.0
		var cx: float = side * (56.0 + length / 2.0)
		_add(village, P.box(length, 2.4, 8.0), P.stone("8f8a7e"), Vector3(cx, RAIL_Y - 1.2 - 0.25, RAIL_Z))
		var rails := Buildings._rails(length, Color("9a948c"), Color("6f5b4a"))
		rails.position = Vector3(cx, RAIL_Y, RAIL_Z); village.add_child(rails)
	# distant farmsteads, and the bell towers of the next villages
	for f in [[-190, -120, 0.3, true], [170, -160, 1.1, false], [230, 70, 0.6, true], [-240, 95, 2.0, false], [45, 220, 1.4, true],
			[-95, -235, 0.2, false], [130, 250, 2.6, false], [-150, 205, 0.9, true]]:
		_farmstead(village, Vector3(f[0], -0.4, f[1]), f[2], f[3])

static func _farmstead(village: Node3D, at: Vector3, r: float, tower: bool) -> void:
	var g := Node3D.new(); g.position = at; g.rotation.y = r; village.add_child(g)
	_add(g, P.box(34, 0.8, 26), P.mat(BANK.darkened(0.05)), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, false)
	var walls := ["d9c49a", "b8664c", "e3c98f"]
	for k in 3:
		var b := {"w": [16.0, 10.0, 7.0][k], "d": [6.0, 5.0, 8.0][k]}
		var p: Vector3 = [Vector3(0, 0.6, -6), Vector3(-7, 0.6, 5), Vector3(8, 0.6, 4)][k]
		var h: float = [6.0, 5.0, 4.0][k]
		_add(g, P.box(b.w, h, b.d), P.plaster(walls[k]), p + Vector3(0, h / 2.0, 0), Vector3.ZERO, Vector3.ONE, false)
		var roof := MeshInstance3D.new(); roof.mesh = Props.gable_roof_mesh(b.w if b.w >= b.d else b.d, b.d if b.w >= b.d else b.w, 1.8, 0.4)
		roof.material_override = Props.roof_material("a5503a"); roof.position = p + Vector3(0, h, 0)
		if b.w < b.d: roof.rotation.y = PI / 2
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(roof)
	if tower:
		_add(g, P.box(3.0, 18.0, 3.0), Tex.brick(Color("b8664c")), Vector3(13, 9.6, -10), Vector3.ZERO, Vector3.ONE, false)
		_add(g, P.cyl(0.02, 2.0, 4.0, 8), P.mat("8f4a36"), Vector3(13, 20.6, -10), Vector3.ZERO, Vector3.ONE, false)

static func _multimesh(village: Node3D, mesh: Mesh, mat: Material, xfs: Array, shadow: bool) -> void:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh; mm.instance_count = xfs.size()
	for i in xfs.size(): mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	village.add_child(mi)
