extends RefCounted
## Casalrana (rice_village). Stage 1: the ground and the map make a playable world. You arrive at the bus stop, can
## walk everywhere the village needs, can't walk onto the railway except at the level crossing, and the canal, the
## spring pool and the winter paddy are where the design puts them. Build sites are on dry ground, the weather is
## always clear, and the ground is painted (stubble, gravel, brick) rather than meadow. Stage 2: the buildings, rooms
## you can walk into and scenery build without errors, and the trains keep to a timetable that closes the level
## crossing before they reach it. See docs/locations/rice_village.md.
var t

const ID := "rice_village"
const RV := preload("res://scripts/locations/rice_village.gd")
const TT := preload("res://scripts/locations/rice_village/timetable.gd")
const Trains := preload("res://scripts/locations/rice_village/trains.gd")

## Stand-ins for the game and the player, enough for the trains and the crossing.
class FakePlayer:
	var pos := Vector3.ZERO
	func teleport(x: float, z: float, _yaw = null) -> void: pos = Vector3(x, 0.0, z)
class FakeGame:
	var walk: WalkWorld
	var state := {"time": {"day": 3, "minute": 600.0, "total": 0.0}, "flags": {}}
	var traveling := false
	var player := FakePlayer.new()
	var toasts: Array = []
	func toast(text: String, _kind: String = "", _life: float = 0.0) -> void: toasts.append(text)

## Runs `fn` with Casalrana loaded, then always switches back to Monteforchetta for the other tests.
func _here(fn: Callable) -> void:
	Data.use_island(ID)
	fn.call()
	Data.use_island("hearthglow")

func _world() -> WalkWorld:
	return WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return false)

func _stand(w: WalkWorld, x: float, z: float) -> bool:
	return not w.can_stand(x, z, Heightfield.height(x, z), 0.3).is_empty()

func test_it_is_a_location_pack():
	t.ok(Data.location_ids().has(ID), "Casalrana is a location pack")
	var isl := Data.island_def(ID)
	t.eq(isl.get("name", ""), "Casalrana", "its map entry is named")
	t.ok(not Travel.on_map(isl, {}, "hearthglow"), "it stays off the travel map until the bus line reaches it")
	t.ok(Travel.on_map(isl, {"rice_village_revealed": true}, "hearthglow"), "and shows once it's revealed")
	t.ok(Travel.on_map(isl, {}, ID), "and always while you're there")
	t.eq(isl.get("look", {}).get("weather", []), ["clear"], "its look allows only clear weather")

func test_you_arrive_at_the_bus_stop():
	_here(func():
		var w := _world()
		var sp: Dictionary = Data.layout.spawn
		t.ok(_stand(w, sp.x, sp.z), "you step off the bus onto open ground")
		var stop: Array = Data.layout.features.filter(func(f): return f.kind == "boat" and not f.has("flag"))
		t.eq(stop.size(), 1, "one departure point from the start")
		t.eq(stop[0].get("depart_label", ""), "Catch the bus", "it's the bus stop")
		var platform: Array = Data.layout.features.filter(func(f): return f.kind == "boat" and f.has("flag"))
		t.eq(platform.size(), 1, "and one more once the trains stop again")
		t.eq(platform[0].flag, TT.STOP_FLAG, "the platform, after the finale")
		t.ok(Rect2(5, -44, 28, 2).has_point(Vector2(platform[0].x, platform[0].z)), "on the platform")
		t.ok(Vector2(stop[0].x - sp.x, stop[0].z - sp.z).length() < 2.6, "the bus stop is where you arrive")
		t.eq(Data.layout.get("arrive", {}), Data.layout.spawn, "arriving later puts you at the same stop"))

func test_every_nav_spot_can_be_walked_to():
	_here(func():
		var w := _world()
		var sp: Dictionary = Data.layout.spawn
		var start := Schedule.nearest_node(sp.x, sp.z, {})
		t.eq(start, "busStop", "the walk starts at the bus stop")
		for k in Data.layout.nav_nodes:
			t.ok(not Schedule.find_path(start, k, {}).is_empty(), "the nav graph reaches %s" % k)
		# walkers follow each edge in a straight line: no water or obstacles along the way
		for e in Data.layout.nav_edges:
			var a: Array = Data.layout.nav_nodes[e[0]]; var b: Array = Data.layout.nav_nodes[e[1]]
			var ok := true
			for s in 41:
				var x: float = lerpf(a[0], b[0], s / 40.0); var z: float = lerpf(a[1], b[1], s / 40.0)
				if not _stand(w, x, z): ok = false
			t.ok(ok, "the way from %s to %s is open ground" % [e[0], e[1]]))

func test_the_railway_is_closed_except_at_the_crossing():
	_here(func():
		var w := _world()
		for x in [-50.0, -20.0, -3.0, 8.0, 19.0, 45.0]:
			t.ok(not _stand(w, x, RV.RAIL_Z), "no walking on the line at x %.0f" % x)
		t.ok(_stand(w, 2.0, RV.RAIL_Z), "the level crossing is open")
		var a: Array = Data.layout.nav_nodes.crossingS; var b: Array = Data.layout.nav_nodes.crossingN
		t.ok(a[1] > RV.RAIL_Z and b[1] < RV.RAIL_Z, "the crossing joins both sides of the line")
		var tracks: Array = Data.layout.buildings.filter(func(bd): return bd.kind == "rice_village_track")
		t.eq(tracks.size(), 2, "the railway bed is two blocks with the crossing between them")
		t.ok(tracks.all(func(bd): return float(bd.h) < 1.5), "the camera can look over the railway bed"))

func test_water_where_the_design_puts_it():
	_here(func():
		t.ok(Heightfield.is_water(RV.CANAL_X, 0.0) and Heightfield.is_water(RV.CANAL_X, -30.0), "the canal can't be walked")
		var dry := 0; var puddles := 0
		for z in range(-50, 51):
			var h := Heightfield.height(RV.CANAL_X, float(z))
			if h > Heightfield.WATER_Y: dry += 1
			else: puddles += 1
		t.ok(dry > 60 and puddles > 10, "the canal is drained: a muddy bed with puddles (%d dry, %d puddles)" % [dry, puddles])
		t.ok(Heightfield.is_stream_cell(-41, 0) and Heightfield.is_stream_cell(-40, -30), "the canal flows for waterwheels")
		t.ok(not Heightfield.is_stream_cell(-30, 0) and not Heightfield.is_stream_cell(2, -6), "the fields and the village don't")
		var wc := RV.WINTER.get_center()
		t.ok(Heightfield.is_water(wc.x, wc.y) and Heightfield.height(wc.x, wc.y) > Heightfield.WATER_Y, "the winter paddy is sunken and dry until it's flooded")
		t.ok(Heightfield.height(RV.POOL.x, RV.POOL.y) < Heightfield.WATER_Y - 0.4, "the spring pool is deep water")
		var mirrors := RV.PUDDLES.filter(func(p): return Heightfield.height(p.x, p.y) < Heightfield.WATER_Y)
		t.eq(mirrors.size(), RV.PUDDLES.size(), "every puddle in the stubble shows the sky")
		t.ok(Heightfield.is_water(0.0, 58.0) and Heightfield.is_water(-58.0, 0.0), "past the edge the plain runs on as flooded paddies")
		t.ok(not Heightfield.is_water(2.0, -6.0) and absf(Heightfield.height(2.0, -6.0) - RV.PAD) < 0.01, "the crossroads is flat ground")
		for n in Data.layout.nodes:
			if n.kind == "fish": t.ok(Heightfield.is_water(n.x, n.z), "%s is in the spring pool" % n.id))

func test_build_sites_are_on_dry_ground():
	_here(func():
		var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
		for id in ["rice_village_plot", "rice_village_platform", "rice_village_churchyard", "rice_village_bench", "rice_village_goodsYard", "rice_village_tower"]:
			var zn := Data.zone(id)
			t.ok(not zn.is_empty(), "%s exists" % id)
			var wet := 0; var blocked := 0
			for i in range(int(zn.minI), int(zn.maxI) + 1):
				for k in range(int(zn.minK), int(zn.maxK) + 1):
					# the platform has crumbled in three places: those holes are what The Train Stops Here bridges
					var hole: bool = id == "rice_village_platform" and RV.HOLES.any(func(h): return i + 0.5 > h.x and i + 0.5 < h.y)
					if Heightfield.is_water(i + 0.5, k + 0.5) != hole: wet += 1
					var cell := {"minX": i + 0.05, "maxX": i + 0.95, "minZ": k + 0.05, "maxZ": k + 0.95}
					for s in statics:
						var hit := WalkWorld.circle_box(s.x, s.z, s.r, cell) if s.type == "circle" else BuildGrid.overlap2(cell, s)
						if hit: blocked += 1; break
			t.eq(wet, 0, "%s is dry ground" % id)
			t.eq(blocked, 0, "%s is clear of buildings and scenery" % id)
		for id in ["rice_village_mill", "rice_village_paddy", "rice_village_sluice"]:
			var zn := Data.zone(id)
			var flowing := false
			for i in range(int(zn.minI), int(zn.maxI) + 1):
				for k in range(int(zn.minK), int(zn.maxK) + 1):
					if Heightfield.is_stream_cell(i, k): flowing = true
			t.ok(flowing, "%s reaches the canal" % id)
		var plot := Data.zone("rice_village_plot")
		t.eq(plot.get("unlock", {}).get("flag", ""), "rice_village_homePlot", "your yard opens with your flat"))

func test_always_clear():
	_here(func():
		t.eq(Daylight.allowed_here(), ["clear"], "Casalrana allows only clear weather")
		for day in range(1, 20):
			for m in range(0, 1440, 60):
				t.eq(Clock.weather({"day": day, "minute": float(m)}), "sunny", "clear skies on day %d at %d:00" % [day, m / 60]))
	t.eq(Daylight.allowed_here(), [], "back in Monteforchetta any weather can come")

func test_the_ground_is_painted():
	_here(func():
		t.ok(Heightfield.has_paint(), "Casalrana paints its own ground")
		t.eq(Heightfield.meadow(15.0, 28.0), 0.0, "harvested paddies are bare stubble")
		t.eq(Heightfield.meadow(2.0, -20.0), 0.0, "and so are the roads")
		t.ok(Heightfield.meadow(RV.POOL.x + 5.5, RV.POOL.y) > 0.5, "the spring pool's grove stays green")
		var stubble := Heightfield.paint(15.0, 28.0)
		t.ok(stubble.r > stubble.g and stubble.g > stubble.b, "stubble is pale gold-brown")
		var yard := Heightfield.paint(28.0, -7.0)
		t.ok(yard.r > yard.g + 0.1, "the farmstead's yard is brick")
		var decor := WorldStatics.generate_decor()
		t.eq(decor.flowers.size(), 0, "no flowers in late November")
		t.eq(decor.trees.size(), 0, "no stock trees: Casalrana's trees come from its own script")
		t.ok(decor.grass.all(func(g): return Heightfield.meadow(g.x, g.z) >= 0.5), "grass tufts only in the grove"))

func test_ids_carry_the_location_prefix():
	_here(func():
		for kind in ["buildings", "zones", "nodes"]:
			for e in Data.layout[kind]: t.ok(String(e.id).begins_with(ID + "_"), "%s %s starts with %s_" % [kind, e.id, ID])
		for f in Data.layout.features:
			t.ok(String(f.id).begins_with(ID + "_"), "feature %s starts with %s_" % [f.id, ID])
		for b in Data.layout.buildings:
			var model: Node3D = RV.building(b)
			t.ok(model != null, "%s has a model" % b.id)
			if model: model.free())

func test_the_village_builds():
	# Builds the whole place the way the game does (buildings, rooms, scenery, the trains), so mistakes in the models
	# show up here and not only on screen.
	_here(func():
		var v := Village.new()
		v.build(WorldStatics.generate_decor())
		for b in Data.layout.buildings:
			if b.kind == "rice_village_upstairs": continue   # your flat: the station builds it
			t.ok(v.objects.has(b.id) and v.objects[b.id].get_child_count() > 0, "%s is built" % b.id)
		for b in Data.layout.buildings:
			if Interiors.enterable(b): t.ok(v.objects[b.id].has_meta("fade_parts"), "%s's roof and upper floor fade while you're inside" % b.id)
		var poplar: Node3D = v.node_visuals.get("rice_village_poplar0")
		t.ok(poplar != null and poplar.get_node_or_null("ribbon") != null, "the plantation's gathering spots keep the forester's ribbon")
		t.ok(poplar != null and poplar.get_child_count() == 2, "and are bare poplars, not the stock round tree")
		t.ok(v.get_node_or_null("rice_village_trains") != null, "the trains run")
		t.ok(v.get_node_or_null("rice_village_crown") != null and v.get_node_or_null("rice_village_w_shoot") != null, "poplars and willows stand about")
		t.ok(v.window_mats.size() > 20, "windows light up at night (%d)" % v.window_mats.size())
		v.free())

func test_rooms_you_can_walk_into():
	_here(func():
		var rooms: Array = Data.layout.buildings.filter(func(b): return Interiors.enterable(b))
		t.eq(rooms.map(func(b): return b.id), ["rice_village_station", "rice_village_flat", "rice_village_casello", "rice_village_church", "rice_village_tower",
			"rice_village_mill", "rice_village_farmhouse", "rice_village_office", "rice_village_shed"],
			"the station and your flat above it, the cottage, the church and its tower, the mill and the farmstead's kitchen, office and shed")
		var w := _world()
		for b in rooms:
			if b.interior.get("route", []).is_empty(): continue   # your flat and the tower: nobody works there
			t.ok(Data.layout.nav_nodes.has(b.id + ":spot"), "%s has a spot inside to work at" % b.id)
			var spot: Array = Data.layout.nav_nodes[b.id + ":spot"]
			t.ok(_stand(w, spot[0], spot[1]), "%s's spot is free of furniture" % b.id)
		var bench: Array = Data.layout.features.filter(func(f): return f.kind == "rest")
		t.ok(bench.size() == 1 and Interiors.room(Data.layout.buildings[0]).has_point(Vector3(bench[0].x, 0.0, bench[0].z)), "you sleep on the waiting-room bench, inside the station"))

func test_the_timetable():
	var gaps: Array = []
	var kinds := {}
	for day in range(1, 15):
		var list := TT.trains_on(day)
		t.ok(list.size() >= 30 and list.size() <= 48, "day %d has a busy line (%d trains)" % [day, list.size()])
		t.eq(list.filter(func(tr): return tr.kind == "inspection").size(), 1, "one yellow inspection train on day %d" % day)
		for i in list.size():
			var tr: Dictionary = list[i]
			kinds[tr.kind] = true
			if tr.kind == "night_express": t.ok(TT.is_night(tr.minute), "the night express runs only at night (%.0f)" % tr.minute)
			if tr.kind == "inspection": t.ok(tr.minute > 300.0 and tr.minute < 470.0, "the inspection train comes at dawn (%.0f)" % tr.minute)
			if i > 0: gaps.append(tr.minute - list[i - 1].minute)
	t.eq(kinds.keys().size(), 5, "all five kinds of train run (%s)" % [kinds.keys()])
	t.ok(gaps.min() >= 30.0 and gaps.max() <= 44.0, "a train every half hour or so (%.0f to %.0f minutes)" % [gaps.min(), gaps.max()])
	t.eq(TT.trains_on(5), TT.trains_on(5), "the same day always has the same trains")

func test_the_crossing_closes_before_every_train():
	var closed_with_train := 0
	for day in [2, 7]:
		for m in range(0, 1440 * 4):
			var minute := m / 4.0
			var on := TT.at_crossing(day, minute)
			if not on.is_empty():
				t.ok(TT.crossing_closed(day, minute), "no train on the crossing while it's open (day %d, %.2f)" % [day, minute])
				closed_with_train += 1
		var open_minutes := 0
		for m in 1440:
			if not TT.crossing_closed(day, float(m)): open_minutes += 1
		t.ok(open_minutes > 1440 * 0.6, "the crossing is open most of the time (%d of 1440 minutes on day %d)" % [open_minutes, day])
	t.ok(closed_with_train > 50, "trains go over the crossing (%d samples)" % closed_with_train)
	var tr0: Dictionary = TT.trains_on(4)[3]
	t.ok(TT.crossing_closed(4, tr0.minute - TT.LEAD + 0.5) and not TT.crossing_closed(4, tr0.minute - TT.LEAD - 1.0), "the barriers come down %.0f minutes before the train" % TT.LEAD)

func test_the_barriers_keep_you_off_the_line():
	_here(func():
		var g := FakeGame.new()
		g.walk = _world()
		var parent := Node3D.new()
		var tr: Node3D = Trains.new()
		parent.add_child(tr)
		tr.setup(g, parent)
		t.eq(g.walk.dynamic.size(), 6, "six bodies wait across the two mouths of the crossing")
		var train: Dictionary = TT.trains_on(3)[10]
		g.state.time = {"day": 3, "minute": train.minute - TT.LEAD - 2.0, "total": 0.0}
		tr._process(0.016)
		t.ok(_stand(g.walk, 2.0, RV.RAIL_Z), "with no train coming, you can cross")
		g.player.pos = Vector3(2.0, 0.6, RV.RAIL_Z)
		g.state.time.minute = train.minute - 1.0
		tr._process(0.016)
		t.ok(not _stand(g.walk, 2.0, -44.3) and not _stand(g.walk, 2.0, -49.7), "as a train comes, the barriers close the crossing")
		t.ok(g.player.pos.z > -44.0 or g.player.pos.z < -50.0, "and whoever was on it steps back off (%s)" % g.player.pos)
		t.eq(g.toasts.size(), 1, "with a word about the bells")
		t.ok(tr.get_child_count() >= 1, "the train is on show as it nears")
		g.state.time.minute = train.minute + TT.length_of(train.kind) / float(TT.KINDS[train.kind].speed) + TT.CLEAR + 1.0
		tr._process(0.016)
		if not TT.crossing_closed(3, g.state.time.minute): t.ok(_stand(g.walk, 2.0, -44.3), "once it has passed, the crossing opens again")
		parent.free())

# ---- Stage 3: people, dialogue and requests --------------------------------------------------------------------
## The walk world the game uses: statics, the layout's raised floors and what you've built.
func _full_world(pls: Array = []) -> WalkWorld:
	var w := _world(); w.floors = WorldStatics.floors(); w.surfaces = BuildGrid.surfaces_for(pls)
	return w

## Places pieces one by one the way build mode checks them (site open, support, nothing in the way); returns the
## reasons any were refused.
func _place_all(pls: Array, open_zones: Array) -> Array:
	var zones: Array = Data.layout.zones.filter(func(z): return open_zones.has(z.id))
	var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
	var placed: Array = []; var refused: Array = []
	for p in pls:
		var ctx := {"placements": placed, "zones": zones, "statics": statics, "harmony": 0, "flags": {}}
		var v := BuildGrid.validate_placement(p, ctx)
		if v.ok: placed.append(p)
		else: refused.append("%s at %d,%d: %s" % [p.id, int(p.i), int(p.k), v.reason])
	return refused

func _pl(uid: int, id: String, i: float, k: float, r: int, y: float) -> Dictionary: return {"uid": uid, "id": id, "i": i, "k": k, "r": r, "y": y}

func test_casalranas_people_and_requests():
	var mine: Array = Data.quests.filter(func(q): return Data.quest_island(q.id) == ID)
	t.eq(mine.size(), 11, "eleven requests")
	t.eq(mine.filter(func(q): return q.get("main", false)).map(func(q): return q.id),
		["rice_village_welcome", "rice_village_flat", "rice_village_stairs", "rice_village_nativity", "rice_village_train"], "five main requests, in order")
	var people: Array = Data.npcs.filter(func(n): return n.get("island", "") == ID)
	t.eq(people.size(), 7, "six villagers and the inspector")
	var nav := Data.island_nav(ID)
	for n in people:
		for e in n.schedule: t.ok(nav.has(e[2]), "%s's routine goes to real spots (%s)" % [n.id, e[2]])
		for w in n.get("when", []):
			for e in w.schedule: t.ok(nav.has(e[2]), "%s's other routine goes to real spots (%s)" % [n.id, e[2]])
	t.ok(Data.npc("rice_village_carlo").get("present", "") == "rice_village_inspector", "the inspector only turns up for the finale")
	_here(func():
		for q in mine:
			for o in q.objectives:
				if o.has("zone"): t.ok(not Data.zone(o.zone).is_empty(), "%s builds in a real site (%s)" % [q.id, o.zone])
				if o.has("hint"): t.ok(not Heightfield.is_water(o.hint.x, o.hint.z), "%s's compass hint is on land" % o.id)
				if String(o.get("check", "")).begins_with("fed:"): t.ok(Data.layout.machines.any(func(m): return "fed:" + m.id == o.check), "%s's machine is in the layout" % o.check))
	# the petition: the main story and three side requests reach it; there's more on offer than it needs
	var m := LocationMeter.def(ID)
	t.eq([m.get("name", ""), LocationMeter.reward_text(m, 20)], ["The Petition", "✍️ +20 signatures"], "Casalrana's meter is Paletta's petition")
	var total := 0; var main := 0
	for q in mine:
		total += int(q.get("rewards", {}).get("meter", 0))
		if q.get("main", false): main += int(q.get("rewards", {}).get("meter", 0))
	t.ok(total >= 300 and main < 250 and main + 85 >= 250, "320 signatures on offer, the main story needs a few side requests (%d, main %d)" % [total, main])
	t.eq(m.milestones.map(func(x): return int(x.at)), [40, 90, 140, 200, 250], "milestones")
	var fin: Array = Data.quest("rice_village_train").objectives.filter(func(o): return o.kind == "meter")
	t.ok(fin.size() == 1 and int(fin[0].value) == 250, "the finale waits for 250 signatures")
	t.ok("rice_village_trainStops" in Data.quest("rice_village_train").rewards.flags, "and opens the line to Toriano")

func test_the_flat_upstairs():
	_here(func():
		var w := _full_world()
		# up the outside stair from the forecourt, onto the landing and in at the flat's door
		var pos := Vector3(25.7, Heightfield.height(25.7, -30.8), -30.8)
		for n in 70: pos = w.step_move(pos, 0.0, -0.15).pos
		t.ok(absf(pos.y - 3.5) < 0.05 and pos.z < -36.4, "the outside stair takes you up to the landing, and its railing keeps you on it (at %s)" % pos)
		pos.z = -37.4
		for n in 40: pos = w.step_move(pos, -0.15, 0.0).pos
		t.ok(absf(pos.y - 3.5) < 0.05 and pos.x < 23.5, "and in through the flat's door (at %s)" % pos)
		var flat: Dictionary = Data.layout.buildings.filter(func(b): return b.id == "rice_village_flat")[0]
		var station: Dictionary = Data.layout.buildings[0]
		t.ok(Interiors.inside(flat, 3.5, pos) and not Interiors.inside(station, 0.42, pos), "upstairs you're in the flat, not the waiting room")
		var down := Vector3(16.0, 0.42, -37.5)
		t.ok(Interiors.inside(station, 0.42, down) and not Interiors.inside(flat, 3.5, down), "downstairs, the waiting room")
	
		# furnishing it: the pieces stand on the flat's floor
		var pls := [_pl(1, "bed", 14, -40, 0, BuildGrid.suggest_bottom("bed", 14, -40, 0, 3.6, [])), _pl(2, "table", 17, -39, 0, BuildGrid.suggest_bottom("table", 17, -39, 0, 3.6, [])),
			_pl(3, "chair", 17, -38, 2, BuildGrid.suggest_bottom("chair", 17, -38, 2, 3.6, [])), _pl(4, "lamp", 20, -40, 0, BuildGrid.suggest_bottom("lamp", 20, -40, 0, 3.6, []))]
		t.ok(pls.all(func(p): return absf(p.y - 3.5) < 0.01), "pieces rest on the flat's floor")
		t.eq(_place_all(pls, ["rice_village_flat"]), [], "a bed, a table, a chair and a lamp fit in the flat")
		var brief: Dictionary = Data.quest("rice_village_flat").objectives.filter(func(o): return o.id == "furnish")[0]
		var r := Commission.evaluate(brief, {"placements": pls})
		t.ok(r.done and r.wishes.any(func(w): return w.ok), "and they furnish it, the lamp in the window for Paletta too"))

func test_the_climb_up_the_bell_tower():
	_here(func():
		var zone := Data.zone("rice_village_tower")
		t.ok(not Validate.path_across(zone, _full_world()).ok, "the rotted stairs: no way up to the ringing floor")
		var g := 0.42
		var pls := [_pl(1, "stairs", -16, 9, 0, g), _pl(2, "stoneBlock", -16, 8, 0, g), _pl(3, "stairs", -16, 8, 0, g + 1.0)]
		t.eq(_place_all(pls, ["rice_village_tower"]), [], "two flights, the second on a stone block, fit inside the tower")
		var r := Validate.path_across(zone, _full_world(pls))
		t.ok(r.ok, "and climb to the ringing floor (reached %s)" % r.get("reached", ""))
		var w := _full_world(pls)
		var pos := Vector3(-15.5, g, 10.6)
		for n in 40: pos = w.step_move(pos, 0.0, -0.12).pos
		t.ok(absf(pos.y - (g + 2.0)) < 0.05 and pos.z < 8.0, "you can walk up it to the bell ropes (at %s)" % pos)
		var tower: Dictionary = Data.layout.buildings.filter(func(b): return b.id == "rice_village_tower")[0]
		t.ok(Interiors.inside(tower, g, pos), "up there you're still in the tower, so its walls stay faded"))

func test_the_platform_and_the_sluice():
	_here(func():
		var plat := Data.zone("rice_village_platform")
		t.ok(not Validate.path_across(plat, _full_world()).ok, "the crumbled platform can't be walked end to end")
		var pls: Array = []
		for h in RV.HOLES:
			for i in range(int(h.x) - 1, int(h.y) + 1):
				var y := BuildGrid.suggest_bottom("bridgeDeck", i, -43, 0, 0.6, pls, plat)
				pls.append(_pl(pls.size() + 1, "bridgeDeck", i, -43, 0, y))
		t.eq(_place_all(pls, ["rice_village_platform"]), [], "planks over the three holes, from the edges")
		t.ok(Validate.path_across(plat, _full_world(pls)).ok, "make one continuous platform")
		var sl := Data.zone("rice_village_sluice")
		t.ok(not Validate.path_across(sl, _full_world()).ok, "the drained canal can't be crossed at the sluice")
		var deck: Array = []
		for i in [-43, -42, -41, -38, -39, -40]:   # out from both banks
			deck.append(_pl(deck.size() + 1, "bridgeDeck", i, -29, 0, BuildGrid.suggest_bottom("bridgeDeck", i, -29, 0, 0.8, deck, sl)))
		deck.append(_pl(20, "pillar", -43, -28, 0, Heightfield.height(-42.5, -27.5))); deck.append(_pl(21, "pillar", -38, -28, 0, Heightfield.height(-37.5, -27.5)))
		deck.append(_pl(22, "lever", -38, -30, 0, Heightfield.height(-37.5, -29.5)))
		t.eq(_place_all(deck, ["rice_village_sluice"]), [], "a walkway, two pillars and a lever at the sluice")
		t.ok(Validate.path_across(sl, _full_world(deck)).ok, "and you can walk across"))

func test_the_waterwheel_machines():
	_here(func():
		var m: Array = Data.layout.machines
		var paddy := [_pl(1, "waterwheel", -39, 10, 1, Heightfield.WATER_Y + 0.05), _pl(2, "pump", -38, 10, 2, Heightfield.height(-37.5, 10.5))]
		for i in range(-37, -33): paddy.append(_pl(paddy.size() + 1, "pipe", i, 10, 1, Heightfield.height(i + 0.5, 10.5)))
		t.eq(_place_all(paddy, ["rice_village_paddy"]), [], "a waterwheel, a pump and pipes fit by the winter paddy")
		t.ok(Mechanics.solve(paddy, m).fed.get("rice_village_paddy", false), "and water reaches the paddy's inlet")
		var mill := [_pl(1, "waterwheel", -39, -13, 1, Heightfield.WATER_Y + 0.05)]
		for i in range(-38, -32): mill.append(_pl(mill.size() + 1, "shaft", i, -13, 1, Heightfield.height(i + 0.5, -12.5)))
		t.eq(_place_all(mill, ["rice_village_mill"]), [], "a waterwheel and shafts fit by the old mill")
		t.ok(Mechanics.solve(mill, m).fed.get("rice_village_mill", false), "and turn the mill's drive"))

func test_gathering_in_casalrana():
	_here(func():
		var straw: Array = Data.layout.nodes.filter(func(n): return n.get("gives", {}).has("rice_village_straw"))
		t.ok(straw.size() >= 6, "loose straw on the stubble (%d)" % straw.size())
		var lost: Array = Data.layout.nodes.filter(func(n): return n.kind == "fragment")
		t.ok(lost.size() == 5 and lost.all(func(n): return n.get("flag", "") == "rice_village_lostThings" and n.has("name")), "five things dropped from the trains, once Paletta asks")
		t.ok(lost.any(func(n): return n.z < RV.RAIL_Z) and lost.any(func(n): return n.z > RV.RAIL_Z), "on both sides of the line")
		var finds: Array = Data.layout.nodes.filter(func(n): return n.kind == "dig")
		var items := {}
		for n in finds:
			for k in n.gives: items[k] = true
		t.ok(items.has("rice_village_coin") and items.has("rice_village_badge") and items.has("rice_village_buttons"), "the metal detector finds the museum's three things")
		t.eq(Gardening.beds().size(), 4, "four garden beds at the farmstead")
		t.ok(Gardening.beds().all(func(b): return b.seed == "rice_village_seeds"), "they grow from Silvia's seed packets")
		var fish := Minigames.catch_table(Data.layout.get("fish", []), "rice_village_pool0", {}, 600.0)
		t.eq(fish.map(func(f): return f.id), ["tench", "carp", "frog"], "the spring pool has tench, carp and a sleepy frog")
		var frog := Minigames.Fish.new(Rng.new(1), [fish[2]]); frog.result = "caught"
		t.eq(frog.reward(), {}, "and the frog goes straight back"))

func test_villagers_keep_out_of_each_others_way():
	# two people on the same spot at the same hour can't both be reached (you talk to whoever's nearer)
	var people: Array = Data.npcs.filter(func(n): return n.get("island", "") == ID)
	var flag_sets := [{}, {"rice_village_welcomed": true}, {"rice_village_welcomed": true, "rice_village_benchBuilt": true, "rice_village_stableBuilt": true}]
	for flags in flag_sets:
		for h in range(0, 24):
			var at := {}
			for n in people:
				if n.has("present") and not flags.get(n.present, false): continue
				var spot: String = Schedule.activity_at(n, h * 60.0 + 30.0, flags).node
				if at.has(spot) and Schedule.activity_at(n, h * 60.0 + 30.0, flags).activity != "sleep":
					t.ok(false, "%s and %s both at %s at %d:30" % [at[spot], n.id, spot, h])
				at[spot] = n.id
	t.ok(true, "nobody shares a spot")

const Wild := preload("res://scripts/locations/rice_village/wildlife.gd")

## Distance from (x, z) to the nearest path line in the layout.
func _path_d(x: float, z: float) -> float:
	var best := 1000.0
	for p in Data.layout.paths:
		for k in range(p.size() - 1):
			var a := Vector2(p[k][0], p[k][1]); var b := Vector2(p[k + 1][0], p[k + 1][1])
			best = minf(best, Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, b).distance_to(Vector2(x, z)))
	return best

func _in_building(x: float, z: float, pad: float) -> String:
	for b in Data.layout.buildings:
		if Rect2(b.x - b.w / 2.0 - pad, b.z - b.d / 2.0 - pad, b.w + pad * 2.0, b.d + pad * 2.0).has_point(Vector2(x, z)): return b.id
	return ""

func test_the_animals_keep_to_their_places():
	_here(func():
		# herons and egrets wade: every spot is water (a ditch puddle, the spring pool, the flooded plain past the
		# edge), and the winter paddy's spots only count once it's flooded
		for s in Wild.WADE:
			t.ok(Heightfield.height(s.x, s.y) < Heightfield.WATER_Y, "a heron's spot at (%.1f, %.1f) is in water" % [s.x, s.y])
		for s in Wild.PADDY:
			t.ok(RV.WINTER.has_point(s), "the paddy's heron spots are in the winter paddy")
		t.eq(Wild.wade_spots({}).size(), Wild.WADE.size(), "the dry winter paddy has no herons")
		t.eq(Wild.wade_spots({Wild.PADDY_FLAG: true}).size(), Wild.WADE.size() + Wild.PADDY.size(), "the flooded one does")
		# lapwings feed on open stubble: dry, bare (not the spring grove's grass), off the paths and clear of buildings
		for s in Wild.FIELDS:
			t.ok(Heightfield.height(s.x, s.y) > Heightfield.WATER_Y + 0.2, "lapwings at (%.0f, %.0f) stand on dry ground" % [s.x, s.y])
			t.ok(Heightfield.meadow(s.x, s.y) < 0.5, "on bare stubble, not the grove's grass (%.0f, %.0f)" % [s.x, s.y])
			t.ok(_path_d(s.x, s.y) > 4.5, "away from the paths (%.0f, %.0f: %.1f m)" % [s.x, s.y, _path_d(s.x, s.y)])
			t.eq(_in_building(s.x, s.y, 4.0), "", "clear of buildings (%.0f, %.0f)" % [s.x, s.y])
		# the paddock and the hens are out of everyone's way: no path, nav spot or gathering spot inside
		var pad := Wild.PADDOCK.grow(0.6)
		for k in Data.layout.nav_nodes:
			var n: Array = Data.layout.nav_nodes[k]
			t.ok(not pad.has_point(Vector2(n[0], n[1])), "nav spot %s is outside the paddock" % k)
			t.ok(Vector2(n[0], n[1]).distance_to(Wild.HENS) > 2.5 or k == "courtyard", "the hens aren't on %s" % k)
		for n in Data.layout.nodes:
			t.ok(not pad.has_point(Vector2(n.x, n.z)), "%s is outside the paddock" % n.id)
		var pb: Array = Data.layout.buildings.filter(func(b): return b.id == "rice_village_paddock")
		t.ok(pb.size() == 1 and Rect2(pb[0].x - pb[0].w / 2.0, pb[0].z - pb[0].d / 2.0, pb[0].w, pb[0].d).is_equal_approx(Wild.PADDOCK), "the paddock's fence is solid: a box in the layout round the herd")
		t.ok(_path_d(Wild.PADDOCK.get_center().x, Wild.PADDOCK.get_center().y) > 6.0, "and no path runs through it")
		var w := _world()
		t.ok(not _stand(w, Wild.PADDOCK.get_center().x, Wild.PADDOCK.get_center().y), "you can't walk in among the cows")
		t.ok(_stand(w, 46.3, -4.4), "but you can stand at the fence by the donkey")
		t.ok(_stand(w, 44.6, 1.0), "and squeeze between the cowshed and the fence")
	)

func test_startled_birds_fly_away_from_you():
	var spots := [Vector2(0, 0), Vector2(10, 0), Vector2(-20, 0), Vector2(0, 30)]
	t.ok(Wild.startled(Vector2(0, 0), Vector2(3, 0), Wild.SHY.heron), "a heron takes off when you're 3 m away")
	t.ok(not Wild.startled(Vector2(0, 0), Vector2(9, 0), Wild.SHY.heron), "and stays put at 9 m")
	t.eq(Wild.next_spot(spots, [], Vector2(5, 0), Vector2(0, 0)), Vector2(0, 30), "it flies to the spot farthest from you")
	t.eq(Wild.next_spot(spots, [Vector2(0, 30)], Vector2(5, 0), Vector2(0, 0)), Vector2(-20, 0), "unless another bird is there")
	t.eq(Wild.next_spot([Vector2(0, 0)], [], Vector2(5, 0), Vector2(0, 0)), Vector2(0, 0), "with nowhere else to go it stays")
	# cranes pass high over the plain twice on most days, by the clock, for a little under an hour of game time
	var days_with := {}
	for day in range(1, 10):
		var passes := 0; var was := false
		for m in range(0, 1440):
			var k := Wild.crane_pass(day, float(m))
			if k >= 0.0 and not was: passes += 1
			was = k >= 0.0
			if k >= 0.0: t.ok(m >= 9 * 60 and m < 17 * 60, "cranes only by day (day %d, %d min)" % [day, m])
		t.ok(passes == 1 or passes == 2, "one or two crane crossings on day %d (%d)" % [day, passes])
		days_with[passes] = true
	t.ok(days_with.has(1) and days_with.has(2), "some days have two crossings and some one")

func test_after_the_finale_the_regional_stops_at_the_platform():
	# the westbound regionals stop (on the platform's track); the others still run through
	var day := 5
	var stopping: Array = TT.trains_on(day).filter(func(tr): return TT.stops_here(tr, true))
	t.ok(stopping.size() > 0, "regionals call at Casalrana on day %d (%d)" % [day, stopping.size()])
	t.ok(stopping.all(func(tr): return tr.kind == "regional" and tr.dir < 0), "only westbound regionals")
	t.ok(TT.trains_on(day).all(func(tr): return not TT.stops_here(tr, false)), "and none before the finale")
	var tr: Dictionary = stopping[0]
	var stood := 0.0; var moved_back := false; var last := -1000.0
	for k in range(-200, 400):
		var dt := k * 0.1
		var s := TT.travel(tr, dt, true)
		if s < last - 1e-4: moved_back = true
		last = s
		if absf((TT.CROSS_X + tr.dir * s) - TT.STOP_X) < 0.01: stood += 0.1
		t.ok(absf(TT.time_at(tr, s, true) - dt) < 0.05 or absf(s - TT.travel(tr, TT.time_at(tr, s, true), true)) < 0.05, "time_at undoes travel (%.1f min)" % dt)
	t.ok(not moved_back, "it never runs backwards")
	t.ok(absf(stood - TT.DWELL) < 0.35, "it stands at the platform for %.0f minutes (%.1f)" % [TT.DWELL, stood])
	# the barriers: never a train on the crossing while it's open, and the stopped train never on it
	for d in [day]:
		for m in range(0, 1440 * 4):
			var minute := m / 4.0
			var on := TT.at_crossing(d, minute, true)
			if not on.is_empty(): t.ok(TT.crossing_closed(d, minute, true), "no train on the open crossing (%.2f)" % minute)
			for x in TT.on_line(d, minute, true):
				if x.stopped:
					t.ok(minf(x.front, x.front - x.dir * x.length) > TT.CROSS_X + 3.0, "the waiting train stands clear of the crossing")
	var leaves := float(tr.minute) + TT.time_at(tr, (TT.STOP_X - TT.CROSS_X) * tr.dir, true)   # where it stands, it's the moment it pulls away
	for before in [1.0, TT.DWELL - 1.0]:
		var waits := TT.on_line(day, leaves - before, true).filter(func(x): return x.n == tr.n and x.day == day)
		t.ok(waits.size() == 1 and waits[0].stopped, "%.0f minutes before it pulls away it's waiting at the platform" % before)
	t.ok(TT.crossing_closed(day, leaves - 1.0, true), "with the barriers already down")
