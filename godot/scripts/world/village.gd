class_name Village
extends Node3D
## Builds the island you're on from its layout data: terrain, water, buildings, decor, resource nodes, features,
## and scenery props (layout `props`; Hearthglow's older dressing is built in code below).
const P := preload("res://scripts/world/palette.gd")

var objects: Dictionary = {}
var node_visuals: Dictionary = {}
var lamps: Array = []
var lamp_glow := 0.0
var lamp_bulbs: Array = []    # indoor lamps (build-piece models) that glow at night
var window_mats: Array = []   # house window glass, lit warm at night
var occluders: Array = []     # [centre, radius] of canopies and bushes, for camera framing
var terrain: MeshInstance3D
var water: MeshInstance3D

func build(decor: Dictionary) -> void:
	terrain = TerrainBuilder.build_terrain(); add_child(terrain)
	water = TerrainBuilder.build_water(terrain); add_child(water)
	var H := func(x: float, z: float) -> float: return Heightfield.height(x, z)
	# A location pack's script may build its own kinds of building (building(b) returns a Node3D, or null to use the
	# shared ones) and add scenery of its own (dress(village)). See docs/WORLD.md.
	var pack = Data.location_script(Data.island)
	var pack_fns: Array = pack.get_script_method_list().map(func(m): return m.name) if pack else []
	for b in Data.layout.buildings:
		var o: Node3D = pack.building(b) if pack_fns.has("building") else null
		if o == null:
			match b.kind:
				"workshop": o = Props.workshop(b)
				"castle": o = Props.castle(b)
				"caravan": o = Props.caravan(b)
				"lighthouse": o = Props.lighthouse(b)
				"clocktower": o = Props.clocktower(b)
				_: o = Props.cottage(b)
		o.position = Vector3(b.x, Heightfield.CASTLE_MOUND.y if b.kind == "castle" else maxf(0.0, H.call(b.x, b.z)), b.z)
		o.name = b.id; add_child(o); objects[b.id] = o
		if Interiors.enterable(b): _furnish(b, o.position.y + (Props.CASTLE_FLOOR if b.kind == "castle" else 0.0))
		for gl in o.get_meta("glasses", []): window_mats.append(gl.material_override)
		for ln in o.find_children("inn_lantern", "MeshInstance3D", true, false): window_mats.append(ln.material_override)
	if Data.island == "hearthglow": _dress_hearthglow(H)
	_build_props()
	_build_decor(decor)
	_build_nodes()
	_build_features()
	if pack_fns.has("dress"): pack.dress(self)

## Hearthglow's scenery: fountain, harbor cliffs and gate, market stall, dock pilings, the broken bridge, lamp
## posts, fences, garden beds and the west pier.
func _dress_hearthglow(H: Callable) -> void:
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
		add_child(P.mi(P.cyl(0.2, 0.24, 2.4, 8), P.wood("8a6a50"), Vector3(s[0] + 0.5, -1.0, s[1] + 0.5)))
		add_child(P.mi(P.cyl(0.26, 0.26, 0.08, 8), P.wood("6a4a30"), Vector3(s[0] + 0.5, 0.02, s[1] + 0.5)))
	add_child(P.mi(P.cyl(0.18, 0.22, 2.6, 8), P.wood("8a6a50"), Vector3(4.3, -0.6, 50.4)))
	for bp in [[-1.6, -17.2, 0.3], [1.8, -19.6, -0.4], [-0.4, -20.4, 0.2]]:
		var p := Props.broken_post(); p.position = Vector3(bp[0], -0.2, bp[1]); p.rotation.z = bp[2]; add_child(p)
	var plank := P.mi(P.box(0.9, 0.1, 1.6), P.wood("9a7a5a"), Vector3(1.2, -0.36, -16.6)); plank.rotation = Vector3(0.1, 0.7, 0.15); add_child(plank)
	for l in [[-6, -3], [6, -3], [-6, 7.5], [6.8, 7.2], [-20, 5.2], [-30, 6.6], [2, -12.5], [12.6, 1.2], [4.6, 20.6], [20, 6.8], [7.4, 31.5]]:
		var lp := Props.lamp_post(); lp.position = Vector3(l[0], H.call(l[0], l[1]), l[1]); add_child(lp); lamps.append(lp)
	for fc in [[3.4, -12.2, 4, 0.0], [3.4, -8.0, 4, 0.0], [1.4, -10.1, 4, PI / 2], [-40, 2.5, 3, 0.0], [-40, 7.6, 3, 0.0]]:
		var fe := Props.fence(fc[2]); fe.position = Vector3(fc[0], H.call(fc[0], fc[1]), fc[1]); fe.rotation.y = fc[3]; add_child(fe)
	for bd in [[4.4, -9.4], [6.6, -9.4], [4.4, -11], [6.6, -11]]: add_child(P.mi(P.box(1.6, 0.16, 1.1), P.wood("9a6a45"), Vector3(bd[0], 0.08, bd[1])))
	var pier := P.mi(P.box(7, 0.15, 2.2), P.wood("c49a6c"), Vector3(-48.5, 0.05, 5)); add_child(pier)

## Scenery from the layout: props [{kind, x, z, r?, ...}] with kind lamp_post, fence (n), crate, barrel, gear,
## piece (any build piece model, id), pier (w, d), market_stall, rock.
func _build_props() -> void:
	for pr in Data.layout.get("props", []):
		var o: Node3D
		match String(pr.kind):
			"lamp_post": o = Props.lamp_post(); lamps.append(o)
			"fence": o = Props.fence(int(pr.get("n", 3)))
			"piece": o = PieceMeshes.make(pr.id, pr.get("color", ""))
			"pier": o = Node3D.new(); o.add_child(P.mi(P.box(float(pr.w), 0.15, float(pr.d)), P.wood("c49a6c"), Vector3(0, 0.05, 0)))
			"market_stall": o = Props.market_stall()
			"rock": o = Props.rock(false); o.scale = Vector3.ONE * float(pr.get("s", 1.0))
			_: o = Props.interior_prop(pr.kind)
		var y: float = float(pr.y) if pr.has("y") else Heightfield.height(pr.x, pr.z)
		o.position = Vector3(pr.x, y, pr.z); o.rotation.y = float(pr.get("r", 0.0))
		if pr.has("id") and pr.kind != "piece": o.name = pr.id; objects[pr.id] = o
		add_child(o)

## Furniture inside a building (build-piece models, or interior props), from layout.json.
func _furnish(b: Dictionary, base_y: float) -> void:
	for it in Interiors.items(b):
		var n: Node3D = PieceMeshes.make(it.id, it.color) if it.piece else Props.interior_prop(it.id)
		n.position = Vector3(it.x, base_y, it.z); n.rotation.y = -it.r * PI / 2.0
		n.name = "%s_%s" % [b.id, it.id]
		add_child(n)
		for m in n.find_children("bulb", "MeshInstance3D", true, false): lamp_bulbs.append(m)

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
	for t in round: occluders.append([Vector3(t.x, H.call(t.x, t.z) + 2.0 * t.s, t.z), 1.15 * t.s])
	for t in pine: occluders.append([Vector3(t.x, H.call(t.x, t.z) + 1.6 * t.s, t.z), 0.95 * t.s])
	for b in decor.bushes: occluders.append([Vector3(b.x, H.call(b.x, b.z) + 0.3 * b.s, b.z), 0.55 * b.s])
	_multimesh(P.cyl(0.13, 0.24, 1.5, 9), tint, round, func(t): return [xf.call(Vector3(t.x, H.call(t.x, t.z) + 0.75 * t.s, t.z), Vector3.ONE * t.s), P.TRUNK])
	_multimesh(P.cyl(0.08, 0.16, 0.9, 7), tint, pine, func(t): return [xf.call(Vector3(t.x, H.call(t.x, t.z) + 0.45 * t.s, t.z), Vector3.ONE * t.s), P.TRUNK])
	# Canopies: lumpy blob clusters that sway gently; two shapes so neighbours don't look cloned.
	var leaves := [Color("6cc45e"), Color("7cd062"), Color("5cb86a"), Color("8ad468"), Color("68c47e")]
	var canopy_mat := Foliage.plant_material(0.025, -0.6)
	for variant in 2:
		var group := round.filter(func(t): return int(t.hue * 10.0) % 2 == variant)
		_multimesh(Foliage.canopy(variant), canopy_mat, group, func(t): return [xf.call(Vector3(t.x, H.call(t.x, t.z) + 2.0 * t.s, t.z), Vector3(1.0, 0.95, 1.0) * t.s, t.hue * 6.0), leaves[int(t.hue * leaves.size()) % leaves.size()]])
	var pine_cols := [Color("4aa872"), Color("3f9a6a"), Color("55b07a")]
	_multimesh(Foliage.pine(), Foliage.plant_material(0.012, 0.5), pine, func(t): return [xf.call(Vector3(t.x, H.call(t.x, t.z), t.z), Vector3.ONE * t.s, t.hue * 6.0), pine_cols[int(t.hue * 3.0) % 3]])
	var bush_cols := [Color("72c464"), Color("62b060"), Color("86d470")]
	_multimesh(Foliage.bush(), Foliage.plant_material(0.03, 0.1), decor.bushes, func(b): return [xf.call(Vector3(b.x, H.call(b.x, b.z), b.z), Vector3(1.15, 0.9, 1.0) * b.s, b.hue * 6.0), bush_cols[int(b.hue * 3) % 3]])
	# Flowers: five-petal heads on thin stems; heads and stems sway together.
	_multimesh(Foliage.flower_head(), Foliage.plant_material(0.02, -1.0, false, true), decor.flowers, func(f): return [xf.call(Vector3(f.x, H.call(f.x, f.z) + 0.27 * f.s, f.z), Vector3.ONE * f.s * 1.7, f.x * 3.0, 0.15), P.FLOWERS[int(f.c)]], false)
	_multimesh(P.cyl(0.012, 0.016, 0.27, 4), Foliage.plant_material(0.02 / 0.27, -0.135), decor.flowers, func(f): return [xf.call(Vector3(f.x, H.call(f.x, f.z) + 0.135 * f.s, f.z), Vector3.ONE * f.s), Color("5aa64c")], false)
	# Grass tufts (lit like the ground so they blend into it), plus extra visual-only tufts near the village.
	var grass: Array = decor.grass.duplicate()
	var rng := Rng.new(11)
	var tries := 0
	while tries < 9000 and grass.size() < 4200:
		tries += 1
		var x := rng.range_f(-46, 46); var z := rng.range_f(-44, 42)
		if Heightfield.height(x, z) < 0.02 or WorldStatics.dist_to_paths(x, z) < 1.25: continue
		var sq: Dictionary = Data.layout.get("square", {"x": 0, "z": 0, "r": -1.0})
		if Vector2(x - sq.x, z - sq.z).length() < sq.r + 0.4: continue
		if WorldStatics._near_building(x, z, 0.15) or WorldStatics._in_zone(x, z, 0.3): continue
		grass.append({"x": x, "z": z, "r": rng.range_f(0, TAU), "s": rng.range_f(0.7, 1.35)})
	var grass_cols := [Color("92d86a"), Color("86d062"), Color("a2de76"), Color("8cd466")]
	_multimesh(Foliage.grass_tuft(), Foliage.plant_material(0.16, 0.0, true), grass, func(g): return [xf.call(Vector3(g.x, H.call(g.x, g.z) - 0.01, g.z), Vector3.ONE * g.s, g.r), grass_cols[int(absf(g.x * 13.0 + g.z * 7.0)) % 4]], false)

func _build_nodes() -> void:
	for n in Data.layout.nodes:
		var o: Node3D
		match n.kind:
			"chop": o = Props.round_tree(1.05, fmod(n.x * 7.3, 1.0) if n.x > 0 else fmod(-n.x * 7.3, 1.0)); Props.add_ribbon(o)
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
		if n.kind in ["chop", "fruit", "shake"]: occluders.append([o.position + Vector3(0, 2.0 * o.scale.y, 0), 1.15 * o.scale.y])
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
			"bench": o = PieceMeshes.make("bench"); o.rotation.y = -int(f.get("r", 0)) * PI / 2.0
			_: o = Node3D.new()
		o.position = Vector3(f.x, -0.45 if f.kind == "boat" else Heightfield.height(f.x, f.z), f.z)
		if f.id == "welcomeSign": o.rotation.y = PI / 2
		o.name = f.id; add_child(o); objects[f.id] = o

func update_world(dt: float, t: float, flags: Dictionary) -> void:
	if objects.has("fountain"): Props.animate_fountain(objects.fountain, t, flags.get("fountainFlowing", false))
	for n in Data.layout.nodes:
		if n.kind == "fragment":
			var o: Node3D = node_visuals[n.id]
			if o.visible:
				o.position.y = Heightfield.height(n.x, n.z) + 1.0 + sin(t * 2.0 + n.x) * 0.15
				o.rotation.y = t * 1.5
	if objects.has("harborGate"):
		var open := 1.0 if flags.get("harborOpen", false) else 0.0
		for d in objects.harborGate.get_node("doors").get_children():
			d.rotation.y = lerpf(d.rotation.y, -float(d.get_meta("side")) * open * 1.6, 1.0 - exp(-dt * 2.0))
		objects.harborGate.get_node("seal").visible = not flags.get("harborOpen", false)
	if objects.has("boat"):
		var boat: Node3D = objects.boat
		var bf: Dictionary = {}
		for f in Data.layout.features:
			if f.id == "boat": bf = f
		boat.visible = not bf.has("flag") or flags.get(bf.flag, false)
		if boat.visible: boat.position.y = -0.45 + sin(t * 1.3) * 0.06; boat.rotation.z = sin(t * 0.9) * 0.03
	if objects.has("workshop"):
		var ws: Node3D = objects.workshop
		ws.get_node("clutter").visible = not flags.get("workshopDone", false)
		if flags.get("workshopDone", false): ws.get_node("signGear").rotation.x = t * 1.5
	if objects.has("caravan"): objects.caravan.get_node("cog").rotation.y = t * 0.8
	# machines that come to life when a machine target is fed (lighthouse lamp, clock hands)
	for b in Data.layout.buildings:
		if b.kind in ["lighthouse", "clocktower"] and objects.has(b.id): Props.animate_machine(objects[b.id], b, t, dt, flags.get("fed:" + String(b.get("machine", "")), false), flags.get("night", false))
	var night: bool = flags.get("night", false)
	lamp_glow = lerpf(lamp_glow, 1.0 if night else 0.0, 1.0 - exp(-dt * 1.5))
	for l in lamps:
		(l.get_node("bulb").material_override as StandardMaterial3D).emission_energy_multiplier = 0.15 + 2.6 * lamp_glow
		var li: OmniLight3D = l.get_node("light")
		li.visible = lamp_glow > 0.02; li.light_energy = 1.6 * lamp_glow
	for m in window_mats: (m as StandardMaterial3D).emission_energy_multiplier = 1.4 * lamp_glow
	for bl in lamp_bulbs: (bl.material_override as StandardMaterial3D).emission_energy_multiplier = 0.3 + 2.4 * lamp_glow
