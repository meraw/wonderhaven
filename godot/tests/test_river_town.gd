extends RefCounted
## Boccapioppo (river_town): the ground has the shape docs/locations/river_town.md describes, you can't walk off the
## map, the Alpine river really separates the east bank (only the Roman bridge crosses it until the pontoon bridge
## is built), and every spot on the map can be reached.
var t
const RT := preload("res://scripts/locations/river_town.gd")
const AudioDirector := preload("res://scripts/audio/audio_director.gd")

func _on(fn: Callable) -> void:
	Data.use_island("river_town")
	fn.call()
	Data.use_island("hearthglow")

func test_the_pack_is_loaded():
	t.ok(Data.location_ids().has("river_town"), "Boccapioppo is a location pack")
	var d := Data.island_def("river_town")
	t.eq(d.get("name", ""), "Boccapioppo", "its map entry is named")
	t.ok(d.get("reveal", "") == "river_town_revealed" and not Travel.on_map(d, {}, "hearthglow"), "it stays off the travel map until the bus line reveals it")
	t.ok(Travel.on_map(d, {"river_town_revealed": true}, "hearthglow"), "...and turns up once it does")
	t.ok(d.get("look", {}).has("light"), "it has its own look")

func test_ground_shape():
	_on(func():
		var H := func(x: float, z: float) -> float: return Heightfield.height(x, z)
		t.ok(H.call(0, 50) < Heightfield.WALKABLE_MIN and H.call(-40, 45) < Heightfield.WALKABLE_MIN, "the Po runs along the south")
		t.ok(Heightfield.is_water(RT.alpine_center(-10.0), -10.0), "the Alpine river runs down the east side")
		t.ok(Heightfield.is_stream_cell(floor(RT.alpine_center(5.0)), 5) and Heightfield.is_stream_cell(28, 6), "the Alpine river flows: a waterwheel turns in it")
		t.ok(not Heightfield.is_stream_cell(0, 50) and not Heightfield.is_stream_cell(-24, 35) and not Heightfield.is_stream_cell(-56, 0), "the Po, the backwater and the canals are still water")
		var town: float = H.call(-20, 0)
		var crest: float = H.call(-30, RT.LEVEE_Z)
		var flood: float = H.call(-30, 31)
		t.ok(town > 0.3 and flood > Heightfield.WALKABLE_MIN and flood < town, "the floodplain lies below the town (%.2f < %.2f)" % [flood, town])
		t.ok(crest - town > 2.0 and crest - flood > 2.0, "the levee stands well above both sides (%.2f)" % crest)
		t.ok(H.call(RT.LEVEE_X, -10) - town > 2.0, "the levee turns north along the Alpine river")
		t.ok(H.call(5, RT.LEVEE_Z) < crest - 1.5, "the breach is a gap in the levee")
		t.ok(H.call(RT.PIAZZA.x, RT.PIAZZA.z) < town - 0.15, "the piazza is the lowest part of town")
		t.ok(Heightfield.is_water(RT.SUMP.x, RT.SUMP.y), "the old sump at the piazza's edge holds water")
		t.ok(Heightfield.is_water(RT.BACKWATER.x, RT.BACKWATER.z), "the backwater lies on the floodplain")
		t.ok(not Heightfield.is_water(RT.SANDBANK.x, RT.SANDBANK.z), "the sandbank reaches out into the Po")
		t.eq(Ground.kind_at(RT.PIAZZA.x, RT.PIAZZA.z), "setts", "the piazza is paved, so no grass grows in it")
		t.ok(H.call(RT.alpine_center(RT.ROMAN_Z), RT.ROMAN_Z) > 1.5, "the Roman bridge's walkway arches over the river")
		var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "river_town_ermes_house")[0]
		t.ok(absf(H.call(b.x, b.z) - town) < 0.15 and H.call(b.x, b.z + b.d / 2.0 + 4.5) > crest - 0.1, "the warden's house stands at the foot of the levee, the levee road just behind it")
		t.ok(absf(H.call(16.0, 31.5) - RT.DANCE_H) < 0.01 and H.call(16.0, 31.5) - H.call(16.0, 36.0) > 0.6, "the dance hall's floor is a raised platform above the floodplain"))

## Cells you can walk to from the bus stop, stepping half a metre at a time over the bare ground (buildings and
## trees left out). `cut` marks cells to treat as blocked.
func _reachable(cut: Callable = func(_x, _z): return false) -> Dictionary:
	var w := WalkWorld.new([])
	var step := 0.5
	var sp: Dictionary = Data.layout.spawn
	var start := Vector2i(roundi(sp.x / step), roundi(sp.z / step))
	var seen := {start: Heightfield.height(sp.x, sp.z)}
	var open := [start]
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if seen.has(n) or absi(n.x) > 140 or absi(n.y) > 140: continue
			var x := n.x * step; var z := n.y * step
			if cut.call(x, z): continue
			var s := w.can_stand(x, z, seen[c], 0.0)
			if s.is_empty(): continue
			seen[n] = s.y
			open.append(n)
	return seen

func test_you_cant_walk_off_the_map():
	_on(func():
		var seen: Dictionary = _reachable()
		var far := 0.0
		for c in seen: far = maxf(far, maxf(absf(c.x * 0.5), absf(c.y * 0.5)))
		t.ok(far < 55.0, "canals and the Po keep you on the map (furthest point %.1f m from the centre)" % far)
		t.ok(seen.has(Vector2i(90, 24)), "the east bank is reachable over the Roman bridge (beside the sawmill)")
		t.ok(seen.has(Vector2i(-48, 58)), "the floodplain is reachable (the houseboat)")
		t.ok(seen.has(Vector2i(10, 8)), "the town is reachable (the piazza)")
		var no_bridge := _reachable(func(x, z): return absf(z - RT.ROMAN_Z) < 2.0 and x > 20.0 and x < 38.0)
		t.ok(not no_bridge.has(Vector2i(90, 24)), "without the Roman bridge the east bank is cut off: the river is a real barrier"))

func test_every_spot_can_be_reached():
	_on(func():
		for k in Data.layout.nav_nodes:
			t.ok(not Schedule.find_path("busStop", k, {}).is_empty(), "the nav graph reaches %s from the bus stop" % k))

func test_build_zones_fit_their_jobs():
	_on(func():
		var bridge := Data.zone("river_town_bridge")
		var ends: Dictionary = bridge.endpoints
		t.ok(not Heightfield.is_water(ends.a.minI + 0.5, ends.a.minK + 1.5) and not Heightfield.is_water(ends.b.minI + 0.5, ends.b.minK + 1.5), "the pontoon bridge site starts and ends on dry banks")
		var wet := 0
		for i in range(bridge.minI, bridge.maxI + 1): if Heightfield.is_water(i + 0.5, 13.5): wet += 1
		t.ok(wet >= 7, "the pontoon bridge has to cross real water (%d cells)" % wet)
		var works := Data.zone("river_town_works")
		var flowing := 0
		for i in range(works.minI, works.maxI + 1):
			for k in range(works.minK, works.maxK + 1): if Heightfield.is_stream_cell(i, k): flowing += 1
		t.ok(flowing >= 4, "the pump works reach the Alpine river, where a waterwheel turns (%d cells)" % flowing)
		var pump: Dictionary = Data.layout.machines.filter(func(m): return m.id == "river_town_pump")[0]
		t.ok(BuildGrid.zone_contains(works, pump.cell[0], pump.cell[1], 999), "the pump works include the pumping house's drive")
		# a waterwheel in the first flowing cell east of the drive, and shafts across the quay: each step down to the
		# wheel within what connects (Mechanics: 0.7)
		var wheel_i: int = pump.cell[0]
		while not Heightfield.is_stream_cell(wheel_i, pump.cell[1]): wheel_i += 1
		var dry := true
		for i in range(pump.cell[0], wheel_i): dry = dry and BuildGrid.ground_at(i, pump.cell[1]) >= Heightfield.WALKABLE_MIN
		var drop := BuildGrid.ground_at(wheel_i - 1, pump.cell[1]) - BuildGrid.suggest_bottom("waterwheel", wheel_i, pump.cell[1], 1, 0.0, [])
		t.ok(dry and drop <= 0.7 and BuildGrid.zone_contains(works, wheel_i, pump.cell[1], 999), "the quay runs dry from the drive to the river, and a shaft there meets a waterwheel (%.2f m)" % drop)
		var breach := Data.zone("river_town_breach")
		t.ok(breach.minI <= RT.BREACH.x and breach.maxI + 1 >= RT.BREACH.y, "the breach zone spans the whole gap")
		var moor := Data.zone("river_town_mooring")
		var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "river_town_houseboat")[0]
		t.ok(BuildGrid.zone_contains(moor, floor(b.x), floor(b.z + b.d / 2.0 + 0.5), 999), "the mooring zone starts at the houseboat")
		t.ok(BuildGrid.zone_contains(moor, floor(RT.BACKWATER.x), floor(RT.BACKWATER.z - RT.BACKWATER_HALF.y), 999), "and reaches the backwater")
		for z in Data.layout.zones:
			t.ok(String(z.id).begins_with("river_town_"), "zone %s has the location's prefix" % z.id))

## Villagers and the playthrough walk the nav graph in straight lines: every edge must be walkable with the real
## collision (buildings, room walls and furniture, tree trunks, columns, posts), up ramps and over the Roman bridge.
func test_every_nav_edge_is_walkable():
	_on(func():
		var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
		var nodes: Dictionary = Data.layout.nav_nodes
		for e in Data.layout.nav_edges:
			if e.size() > 2: continue   # opens with the story (the pontoon bridge): the playthrough walks it once it's built
			var a: Array = nodes[e[0]]; var b: Array = nodes[e[1]]
			var steps := maxi(1, int(Vector2(b[0] - a[0], b[1] - a[1]).length() / 0.2))
			var feet := Heightfield.height(a[0], a[1])
			var blocked := ""
			for k in range(1, steps + 1):
				var x: float = lerpf(a[0], b[0], float(k) / steps); var z: float = lerpf(a[1], b[1], float(k) / steps)
				var s := w.can_stand(x, z, feet, 0.3)
				if s.is_empty(): blocked = "at %.1f, %.1f" % [x, z]; break
				feet = s.y
			t.ok(blocked == "", "walkable: %s to %s %s" % [e[0], e[1], blocked]))

func test_scenery_props_are_drawn_and_placed():
	_on(func():
		var kinds := {}
		for p in Data.layout.props: kinds[String(p.get("tree", p.kind))] = true
		for k in ["poplar", "column", "willow", "locust", "river_town_column", "river_town_post", "river_town_logs", "lamp_post"]:
			t.ok(kinds.has(k), "the layout places %s" % k)
		for p in Data.layout.props:
			if p.get("solid", true) and p.kind != "river_town_gauge": t.ok(not Heightfield.is_water(p.x, p.z), "%s at %.1f, %.1f stands on land" % [p.get("tree", p.kind), p.x, p.z])
		var Scenery = load("res://scripts/locations/river_town/scenery.gd")
		for k in ["poplar", "column", "willow", "locust", "plane"]:
			t.ok(Scenery.canopy(k).get_surface_count() > 0, "a %s canopy mesh is built" % k))

func test_rooms_you_can_walk_into():
	_on(func():
		var rooms := ["river_town_houseboat", "river_town_dance_hall", "river_town_bar", "river_town_workshop", "river_town_ermes_house", "river_town_pierina_house", "river_town_shack"]
		for id in rooms:
			var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == id)[0]
			t.ok(Interiors.enterable(b), "%s is a room you can walk into" % id)
		var hall: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "river_town_dance_hall")[0]
		t.ok(hall.interior.get("empty", false), "the dance hall stands empty, waiting for its request")
		var feats: Array = Data.layout.features.map(func(f): return f.kind)
		t.ok(feats.has("rest") and feats.has("wardrobe"), "the houseboat has a bed to sleep in and a wardrobe")
		var boat: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "river_town_houseboat")[0]
		for f in Data.layout.features.filter(func(f): return f.kind in ["rest", "wardrobe"]):
			t.ok(Interiors.room(boat).has_point(Vector3(f.x, 0.5, f.z)), "the %s is inside the houseboat" % f.kind))

# ---- Stage 3: the people, their requests, and the story's marks on the place ------------------------------------

static func _building(id: String) -> Dictionary:
	for b in Data.layout.buildings:
		if b.id == id: return b
	return {}

func test_people_and_their_days():
	_on(func():
		var people: Array = Data.npcs.filter(func(n): return n.get("island", "") == "river_town")
		t.eq(people.size(), 9, "nine villagers live in Boccapioppo")
		for n in people:
			t.ok(Data.layout.nav_nodes.has(n.home), "%s has a home here (%s)" % [n.id, n.home])
			var days: Array = [n.schedule]
			for w in n.get("when", []): days.append(w.schedule)
			var sp: Dictionary = Data.layout.spawn
			for d in days:
				for e in d:
					t.ok(Data.layout.nav_nodes.has(e[2]), "%s's day takes them to a real spot (%s)" % [n.id, e[2]])
					var at_spot: Array = Data.layout.nav_nodes.get(e[2], [0, 0])
					t.ok(Vector2(at_spot[0] - sp.x, at_spot[1] - sp.z).length() > 1.5, "%s never stands where the bus leaves you (%s)" % [n.id, e[2]])
		# whoever a step at a set hour needs is up and about, where the story says
		var at := func(npc: String, hour: float, flags: Dictionary) -> Dictionary: return Schedule.activity_at(Data.npc(npc), hour * 60.0, flags)
		var w := {"river_town_welcomed": true}
		t.eq(at.call("river_town_ermes", 23.0, {}).node, "ermesWait", "Ermes meets the bus with his shovel, at any hour")
		t.eq(at.call("river_town_ermes", 14.0, {"river_town_shovel": true}).node, "stormA", "once you've taken it, he waits at the breach for the sand")
		t.eq(at.call("river_town_ermes", 6.0, w).node, "gauge", "Ermes reads his gauge at dawn (the houseboat's launch)")
		var ready := {"river_town_welcomed": true, "river_town_bridge_open": true, "river_town_hall_ready": true}
		t.eq(at.call("river_town_wanda", 21.0, ready).node, "river_town_dance_hall:spot", "Wanda is in her hall in the evening once it's fitted out")
		var dancers := people.filter(func(n): return String(at.call(n.id, 21.0, ready).node).begins_with("hall")).size()
		t.ok(dancers >= 6, "the town comes to the dance in the evening (%d villagers)" % dancers)
		var wall: Dictionary = ready.duplicate(); wall["river_town_wall_built"] = true
		t.eq(at.call("river_town_ermes", 21.0, wall).node, "stormB", "Ermes waits on the levee by the breach once the wall stands")
		var storm: Dictionary = wall.duplicate(); storm["river_town_storm"] = true
		t.ok(at.call("river_town_ermes", 1.0, storm).node == "stormB" and at.call("river_town_ermes", 1.0, storm).activity != "sleep", "...and keeps watch there past midnight on the storm night")
		var watching := people.filter(func(n): return String(at.call(n.id, 21.0, storm).node).begins_with("storm") or at.call(n.id, 21.0, storm).node == "leveeMid").size()
		t.eq(watching, 9, "on the storm night the whole town waits on the levee")
		var after: Dictionary = storm.duplicate(); after["river_town_flood_over"] = true
		t.eq(at.call("river_town_rina", 10.0, after).node, "river_town_bar:spot", "after the storm, life goes back to normal")
		for n in Data.layout.nav_nodes:
			if String(n).begins_with("storm") or String(n).begins_with("hall"): t.ok(not Schedule.find_path("busStop", n, {}).is_empty(), "villagers can walk to %s" % n)
		# no two villagers stand (or sleep) on the same spot at the same hour, at any point of the story
		for flags in [{}, {"river_town_shovel": true}, w, {"river_town_welcomed": true, "river_town_bridge_open": true}, ready, wall, storm, after]:
			for h in 24:
				var taken := {}
				for n in people:
					var spot: String = at.call(n.id, h + 0.5, flags).node
					t.ok(not taken.has(spot), "%s and %s don't share %s at %d:30" % [taken.get(spot, ""), n.id, spot, h])
					taken[spot] = n.id)

func test_requests():
	_on(func():
		var mine: Array = Data.quests.filter(func(q): return String(q.id).begins_with("river_town_"))
		t.eq(mine.size(), 16, "five main requests, five side requests and six lost things")
		t.eq(mine.filter(func(q): return q.get("main", false)).size(), 5, "five of them tell the main story")
		var m: Dictionary = LocationMeter.def("river_town")
		t.eq(LocationMeter.reading(m, 0), "7.40 m", "the flood gauge starts at the flood's peak")
		t.eq(LocationMeter.reading(m, int(m.milestones[-1].at)), "0.00 m", "its last milestone is zero: the flood is over")
		for q in mine:
			var want := 100 if q.get("main", false) else (10 if String(q.id).contains("lost_") else 50)
			t.eq(int(q.rewards.get("meter", 0)), want, "%s takes %d cm off the gauge" % [q.id, want])
		var total := 0
		for q in mine: total += int(q.rewards.meter)
		t.ok(total >= int(m.milestones[-1].at) and total - 100 < int(m.milestones[-1].at), "everything together brings the gauge to zero, and it can't get there without the finale (%d cm)" % total)
		var gauge_flags: Array = []
		for u in m.milestones: gauge_flags.append_array(u.get("flags", []))
		for f in Bicycle.UPGRADES.values(): t.ok(gauge_flags.has(f), "a gauge milestone gives the bike's %s" % f)
		t.ok(mine.any(func(q): return q.objectives.any(func(o): return o.get("onDone", {}).get("flags", []).has(Bicycle.OWNED))), "a request here gives you the bicycle")
		# what the steps need is in the world: things to find, the monster's spot, fish to catch
		var seen: Dictionary = _reachable()
		for n in Data.layout.nodes:
			if n.has("gives") or n.has("flag"):
				t.ok(seen.has(Vector2i(roundi(n.x / 0.5), roundi(n.z / 0.5))), "%s can be reached on foot" % n.id)
		for q in mine:
			for o in q.objectives:
				if o.kind == "gather" and String(o.item).begins_with("river_town_"):
					t.ok(Data.layout.nodes.any(func(n): return n.get("gives", {}).has(o.item)) or Data.layout.fish.any(func(f): return f.get("item", "") == o.item), "%s: something in Boccapioppo gives %s" % [q.id, o.item])
				if o.kind == "event" and String(o.event).begins_with("fish:"):
					t.ok(Data.layout.fish.any(func(f): return "fish:" + String(f.id) == o.event), "%s: %s bites somewhere" % [q.id, o.event])
		var monster: Dictionary = Data.layout.fish.filter(func(f): return f.id == "river_town_monster")[0]
		var spot: Dictionary = Data.node_def(monster.node)
		t.ok(absf(spot.x - RT.alpine_center(spot.z)) < 8.0 and spot.z > RT.po_bank(spot.x) - 6.0, "the monster bites where the rivers meet")
		t.eq(Minigames.catch_table(Data.layout.fish, monster.node, {}, 22 * 60.0).filter(func(f): return f.id == "river_town_monster").size(), 0, "not before Primo's line")
		t.eq(Minigames.catch_table(Data.layout.fish, monster.node, {"river_town_catfish_night": true}, 22 * 60.0).filter(func(f): return f.id == "river_town_monster").size(), 1, "then after dark")
		var finale: Dictionary = Data.quest("river_town_levee").rewards
		t.ok(finale.flags.has("rice_village_revealed") and Travel.on_map(Data.island_def("rice_village"), {"rice_village_revealed": true}, "river_town"), "the finale sends the bus line on to Casalrana")
		var lost: Array = Data.layout.nodes.filter(func(n): return n.has("flag"))
		t.ok(lost.all(func(n): return n.kind == "fragment" and n.get("once", false)), "the logs and lost things are each found once"))

func test_the_houseboat_floats_once_launched():
	_on(func():
		var mud: Dictionary = _building("river_town_houseboat")
		t.ok(not mud.get("afloat", false) and not Heightfield.is_water(mud.x, mud.z), "she starts stranded on the mud")
		t.ok(Interiors.items(mud).size() > 2, "with the flood's junk in her cabin")
		Data.apply_world_flags({"river_town_launched": true})
		var boat: Dictionary = _building("river_town_houseboat")
		t.ok(boat.get("afloat", false) and Heightfield.is_water(boat.x, boat.z), "once launched she floats in the backwater")
		t.eq(Interiors.items(boat).map(func(it): return it.id), ["bed", "cabinet"], "her cabin is cleared for you to furnish")
		var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
		w.floors = WorldStatics.floors()
		var foot: Array = Data.layout.nav_nodes.jettyFoot; var door: Array = Data.layout.nav_nodes.houseboat
		var feet: float = Heightfield.height(foot[0], foot[1])
		var ok := true
		for k in range(1, 41):
			var s: Dictionary = w.can_stand(lerpf(foot[0], door[0], k / 40.0), lerpf(foot[1], door[1], k / 40.0), feet, 0.3)
			if s.is_empty(): ok = false; break
			feet = s.y
		t.ok(ok, "a gangway and a jetty lead from the bank to her door")
		var deck: Dictionary = w.can_stand(boat.x, boat.z, RT.DECK_Y, 0.3)
		t.ok(not deck.is_empty() and absf(deck.y - RT.DECK_Y) < 0.05, "you stand on her cabin floor, not in the water")
		var cabin: Dictionary = Data.zone("river_town_cabin")
		var room: AABB = Interiors.room(boat)
		t.ok(room.has_point(Vector3(cabin.minI + 0.5, 0.5, cabin.minK + 0.5)) and room.has_point(Vector3(cabin.maxI + 0.5, 0.5, cabin.maxK + 0.5)), "the cabin you furnish is inside her")
		for f in Data.layout.features.filter(func(f): return f.kind in ["rest", "wardrobe"]):
			t.ok(room.has_point(Vector3(f.x, 0.5, f.z)), "her %s went with her" % f.kind)
		t.ok(BuildGrid.ground_at(cabin.minI, cabin.minK) > Heightfield.WALKABLE_MIN, "you can build on her cabin floor")
		Data.apply_world_flags({})
		t.ok(not _building("river_town_houseboat").get("afloat", false), "a save from before the launch finds her on the mud again"))

## What a player builds for the two crossing requests makes the walkable path their checks ask for.
func test_the_crossings_you_build_are_walkable():
	_on(func():
		var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
		w.floors = WorldStatics.floors()
		var bridge: Dictionary = Data.zone("river_town_bridge")
		t.ok(not Validate.path_across(bridge, w).ok, "no way across the Alpine river before anything is built")
		var row: Array = []
		for i in [27, 29, 31, 33, 35]:
			var y := BuildGrid.suggest_bottom("pontoon", i, 13, 1, 0.1, row, bridge)
			var pl := {"uid": 100 + row.size(), "id": "pontoon", "i": float(i), "k": 13.0, "r": 1, "y": y}
			t.ok(BuildGrid.validate_placement(pl, {"placements": row, "zones": [bridge], "statics": []}).ok, "a pontoon moors at %d, 13" % i)
			row.append(pl)
		w.surfaces = BuildGrid.surfaces_for(row)
		var r := Validate.path_across(bridge, w)
		t.ok(r.ok, "a row of five pontoons from the ferry landing to the far bank is a crossing (reached %s cells)" % r.get("reached", "all"))
		var moor: Dictionary = Data.zone("river_town_mooring")
		var slip: Array = []
		for k in [32, 33]:
			var y := BuildGrid.suggest_bottom("bridgeDeck", -24, k, 0, 0.2, slip, moor)
			var pl := {"uid": 200 + slip.size(), "id": "bridgeDeck", "i": -24.0, "k": float(k), "r": 0, "y": y}
			t.ok(BuildGrid.validate_placement(pl, {"placements": slip, "zones": [moor], "statics": []}).ok, "a slipway plank at -24, %d" % k)
			slip.append(pl)
		w.surfaces = BuildGrid.surfaces_for(slip)
		t.ok(Validate.path_across(moor, w).ok, "two planks from beside the houseboat out over the backwater make her slipway"))

## Stage 4: the ground is painted (grey flood mud outside the levee, white pebbles along the Alpine river, the Po's
## sandbank, maize stubble, autumn grass in town) and the two rivers look different: the Alpine river clear, the Po
## brown, with the clear water's plume where they meet.
func test_the_ground_and_the_two_waters():
	_on(func():
		t.ok(Heightfield.has_paint() and Heightfield.has_water_tint(), "Boccapioppo paints its ground and colours its water")
		var bare := 0; var n := 0
		for x in range(-48, -6, 3):
			for z in range(26, 33, 2):
				if Heightfield.height(x, z) < 0.0: continue
				n += 1
				if Heightfield.meadow(x, z) < 0.5: bare += 1
		t.ok(bare > n * 0.7, "the floodplain is mostly bare mud (%d of %d spots), with grass coming back in patches" % [bare, n])
		var mud := Heightfield.paint(-30.0, 28.0)
		t.ok(mud.g <= mud.r and mud.s < 0.3, "the mud is grey-brown, not green (%s)" % mud.to_html(false))
		t.eq(Heightfield.meadow(-10.0, 0.0), 1.0, "the town is grass")
		var gx := RT.alpine_center(-30.0) + RT.ALPINE_HALF + 0.8
		var peb := Heightfield.paint(gx, -30.0)
		t.ok(Heightfield.height(gx, -30.0) > Heightfield.WALKABLE_MIN and peb.v > 0.7 and Heightfield.meadow(gx, -30.0) == 0.0, "white pebbles along the Alpine river (%s)" % peb.to_html(false))
		t.ok(Heightfield.meadow(RT.SANDBANK.x, RT.SANDBANK.z) == 0.0 and Heightfield.paint(RT.SANDBANK.x, RT.SANDBANK.z).v > 0.8, "the Po's sandbank is pale sand")
		t.eq(Heightfield.meadow(-45.0, -45.0), 0.0, "the maize fields north-west of town are stubble")
		var decor := WorldStatics.generate_decor()
		t.ok(decor.grass.all(func(g): return Heightfield.meadow(g.x, g.z) >= 0.5), "no grass tufts on the mud, the pebbles or the stubble")
		# the waters
		var po := Heightfield.water_tint(-20.0, 46.0)
		t.ok(po.a > 0.8 and po.r > po.b + 0.15, "the Po is brown and cloudy (%s, %.2f)" % [po.to_html(false), po.a])
		t.eq(Heightfield.water_tint(RT.alpine_center(-20.0), -20.0).a, 0.0, "the Alpine river is clear")
		var mx := RT.alpine_center(RT.po_bank(30.0))
		var mouth := Heightfield.water_tint(mx, RT.po_bank(mx) + 1.0)
		var down := Heightfield.water_tint(mx + 30.0, RT.po_bank(mx + 30.0) + 1.0)
		t.ok(mouth.a < 0.3 and down.a > 0.8, "where they meet you can see the line: clear at the Alpine river's mouth (%.2f), brown downstream (%.2f)" % [mouth.a, down.a])
		var bw := Heightfield.water_tint(RT.BACKWATER.x, RT.BACKWATER.z)
		t.ok(bw.a > 0.5 and bw.a < po.a, "the backwater is still and green-brown"))

## A thin mist on the water at dawn only, lying below the floodplain so only the water shows it.
func test_mist_on_the_water_at_dawn():
	var M := preload("res://scripts/locations/river_town/mist.gd")
	t.ok(M.amount_at(6.5) > 0.9 and M.amount_at(8.5) > 0.0, "a mist lies on the water at dawn, thinning by mid-morning")
	t.ok(M.amount_at(10.0) == 0.0 and M.amount_at(15.0) == 0.0 and M.amount_at(23.0) == 0.0 and M.amount_at(3.0) == 0.0, "...and none the rest of the day")
	t.ok(M.Y > Heightfield.WATER_Y + 0.1 and M.Y < RT.FLOOD_H - 0.1, "it lies above the water and below the floodplain (%.2f m)" % M.Y)

## Stage 4b: some of the town ride bicycles round town (Bicycle.villager_bike): the postwoman first of all.
func test_who_rides_a_bike():
	_on(func():
		var riders := Data.npcs_here().filter(func(n): return not Bicycle.villager_bike(n).is_empty()).map(func(n): return n.id)
		t.ok(riders.has("river_town_pierina") and riders.size() >= 4, "Pierina and a few others ride bikes (%s)" % ", ".join(riders))
		for n in Data.npcs_here():
			var b := Bicycle.villager_bike(n)
			if b.is_empty(): continue
			t.ok(Color.html_is_valid(b.color) and b.ups.all(func(u): return Bicycle.UPGRADES.has(u)), "%s's bike has a colour and real upgrades" % n.id))

## Stage 4b: coypus on banks beside deep water, cormorants on snags in the Po, the geese on grass outside the farm
## gate, kingfisher perches over the Alpine river, and the cats on dry ground.
func test_the_animals_live_where_they_should():
	_on(func():
		var A := preload("res://scripts/locations/river_town/animals.gd")
		var cs := A.coypu_spots()
		t.ok(cs.size() >= 4, "coypus have banks to live on (%d)" % cs.size())
		for s in cs:
			var land: Vector2 = s[0]; var water: Vector2 = s[1]
			t.ok(not Heightfield.is_water(land.x, land.y) and Heightfield.height(water.x, water.y) < Heightfield.WATER_Y - 0.25, "a coypu's bank at %s has deep water beside it" % land)
		for p in A.SNAGS: t.ok(Heightfield.height(p.x, p.y) < Heightfield.WATER_Y - 0.3, "a cormorant's snag stands in the Po at %s" % p)
		t.ok(Heightfield.height(A.GEESE_HOME.x, A.GEESE_HOME.y) > 0.3 and Heightfield.meadow(A.GEESE_HOME.x, A.GEESE_HOME.y) == 1.0, "the geese live on the grass outside the farm gate")
		for p in A.perches(): t.ok(absf(p.x - (RT.alpine_center(p.z) - RT.ALPINE_HALF)) < 0.5, "a kingfisher's perch on the Alpine river's bank at z %.0f" % p.z)
		var cats: Array = Data.layout.get("wildlife", {}).get("cats", [])
		t.ok(cats.size() >= 3 and cats.all(func(c): return not Heightfield.is_water(c[0], c[1])), "cats sit about on dry ground, one by Gildo's shack waiting for the catch")
		var a = A.make()
		t.ok(a.coypus.size() == cs.size() and a.cormorants.size() == A.SNAGS.size() and a.geese.size() == 5 and a.kingfishers.size() == 2, "they're all built")
		a.free())

## The geese used to shake: they set off and stopped every other frame, and their walking bob switched on and off
## with it. Now each one stands and pecks, then walks somewhere, and its waddle eases in and out.
func test_the_geese_walk_smoothly():
	_on(func():
		var A := preload("res://scripts/locations/river_town/animals.gd")
		var a = A.make()
		var far := Vector2(200.0, 200.0)   # nobody about
		var going: Array = a.geese.map(func(q): return q.going)
		var bob: Array = a.geese.map(func(q): return -1.0)
		var flips := 0; var jump := 0.0; var walked := 0
		for f in 1200:   # 20 seconds at 60 frames a second
			a.t += 1.0 / 60.0
			a._geese(1.0 / 60.0, far, false)
			for k in a.geese.size():
				var q: Dictionary = a.geese[k]
				if q.going != going[k]: flips += 1; going[k] = q.going; walked += 1 if q.going else 0
				var b: float = (q.obj as Node3D).position.y - Heightfield.height(q.pos.x, q.pos.y)
				if bob[k] >= 0.0: jump = maxf(jump, absf(b - bob[k]))
				bob[k] = b
		t.ok(walked >= 5, "the geese walk about (%d walks in 20 s)" % walked)
		t.ok(flips <= 60, "each goose sets off and stops now and then, not every frame (%d starts and stops in 20 s)" % flips)
		t.ok(jump < 0.006, "no goose jolts up and down from one frame to the next (%.3f m)" % jump)
		a.free())

## Stage 4c: the dance-hall music. Every part of the day has a tune of Boccapioppo's own: thin while the hall is
## wrecked (the melody and the bass), fuller once it reopens, and the hall's own waltz in the evenings then.
func test_the_dance_hall_music():
	_on(func():
		var music: Dictionary = Data.island_def("river_town").get("music", {})
		var open := {"river_town_hall_open": true}
		var loud := func(s: Dictionary) -> float:
			var sum := 0.0
			for st in AudioDirector.loop_steps(s):
				for e in AudioDirector.step_events(s, st): sum += float(e[2])
			return sum / AudioDirector.loop_steps(s)
		for part in ["dawn", "morning", "afternoon", "evening", "night"]:
			var before := AudioDirector.song_for(part, false, music)
			var after := AudioDirector.song_for(part, false, music, open)
			t.ok(before.begins_with("river_town_") and after.begins_with("river_town_") and before != after, "%s: %s while the hall is wrecked, %s once it reopens" % [part, before, after])
			for id in [before, after]:
				var s := AudioDirector.song_def(id, music)
				var insts: Array = [s.lead, s.get("bass_inst", "pluck")] + ([s.arp] if s.arp != "" else []) + s.get("comp", []).map(func(c): return c.inst)
				t.ok(insts.all(func(i): return i in AudioDirector.INSTRUMENTS), "%s plays known instruments %s" % [id, insts])
			t.ok(loud.call(AudioDirector.song_def(after, music)) > loud.call(AudioDirector.song_def(before, music)), "%s is fuller once the hall reopens" % part)
		t.eq(AudioDirector.song_for("evening", false, music, open), "river_town_dance", "the evenings get the dance hall's own waltz")
		t.eq(int(AudioDirector.song_def("river_town_dawn", music).get("bar", 16)), 12, "dawn's waltz is in 3/4")
		t.eq(AudioDirector.song_def("river_town_dawn", music).lead, "accordion", "and the accordion plays it"))

## Stage 4c: you can hear which river you're beside: the Alpine river near it, the Po by its bank, neither in town.
func test_the_two_rivers_sound_different():
	_on(func():
		var S := preload("res://scripts/locations/river_town/sounds.gd")
		var ax := RT.alpine_center(-20.0) + RT.ALPINE_HALF + 1.0
		var by_alpine := S.levels(Vector3(ax, 0.3, -20.0))
		var by_po := S.levels(Vector3(-20.0, 0.2, RT.po_bank(-20.0) - 1.0))
		var in_town := S.levels(Vector3(-10.0, 0.5, 0.0))
		t.ok(by_alpine.x > 0.8 and by_alpine.y == 0.0, "beside the Alpine river you hear it rushing (%s)" % by_alpine)
		t.ok(by_po.y > 0.8 and by_po.x == 0.0, "by the Po you hear it lapping (%s)" % by_po)
		t.eq(in_town, Vector2.ZERO, "in the middle of town, neither"))

## Stage 4c: the cast's outfits. Every piece is one the wardrobe knows (nothing falls back to the default clothes),
## and Boccapioppo's own clothes are worn by their owners and given to you by them as friends.
func test_the_cast_dresses_the_part():
	_on(func():
		for n in Data.npcs_here():
			var a: Dictionary = n.appearance
			var s := Chibi.sanitize(a)
			for k in ["top", "bottom", "hat", "accessory", "shoes", "hair"]:
				if a.has(k): t.eq(s[k], a[k], "%s's %s (%s) is a piece the wardrobe has" % [n.id, k, a[k]])
		var by_id := {}
		for n in Data.npcs_here(): by_id[n.id] = n
		t.eq(by_id.river_town_rina.appearance.top, "jacket", "Rina's black waistcoat over a white blouse")
		t.eq(by_id.river_town_primo.appearance.top, "workjacket", "Primo's grey work coat")
		t.eq(by_id.river_town_mattia.appearance.accessory, "discman", "Mattia's Walkman")
		for v in ["river_town_oilskin", "river_town_sawApron", "river_town_postBag"]:
			t.ok(Data.appearance.get("variants", {}).has(v) and Data.appearance.locked.has(v), "%s is in the wardrobe, locked until earned" % v)
			var givers := Data.npcs_here().filter(func(n): return n.get("gifts", []).any(func(g): return g.get("clothes", []).has(v)))
			var wearers := Data.npcs_here().filter(func(n): return n.appearance.values().has(v))
			t.ok(givers.size() == 1 and wearers.size() == 1 and givers[0].id == wearers[0].id, "%s: its owner wears it and gives you one as a friend" % v)
		var r := Chibi.resolve(Chibi.sanitize(by_id.river_town_pierina.appearance))
		t.ok(r.accessory == "backpack" and r.get("accessoryColor", "") == "#8a5a32", "Pierina's post bag is drawn as a leather bag"))

func test_you_cant_step_off_the_roman_bridge():
	_on(func():
		var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
		var z0: float = RT.ROMAN_Z
		var ac: float = RT.alpine_center(z0)
		var off := 0
		for dx in range(-72, 73, 4):
			for zs in [-1.0, 1.0]:
				var pos := Vector3(ac + dx / 10.0, Heightfield.height(ac + dx / 10.0, z0), z0)
				for k in 20: pos = w.step_move(pos, 0.0, zs * 0.15).pos
				if absf(pos.z - z0) > RT.ROMAN_HALF: off += 1
		t.eq(off, 0, "walking sideways along the Roman bridge, wherever it stands above the banks, stops at its parapets")
		var path: Array = Data.layout.nav_nodes.romanWest
		var feet := Heightfield.height(path[0], path[1])
		var across := true
		for k in 80:
			var x: float = lerpf(path[0], float(Data.layout.nav_nodes.romanEast[0]), (k + 1) / 80.0)
			var s := w.can_stand(x, z0, feet, WalkWorld.PLAYER_RADIUS)
			if s.is_empty(): across = false; break
			feet = s.y
		t.ok(across, "and you still walk over it from end to end"))

func test_once_the_hall_is_ready_the_town_dances_there_every_evening():
	var hall := Rect2(11.2, 28.2, 9.6, 6.6)
	var nodes: Dictionary = Data.read_layout("river_town").nav_nodes
	var dancers := 0
	for n in Data.npcs.filter(func(x): return x.get("island", "") == "river_town"):
		for flag in ["river_town_hall_ready", "river_town_flood_over"]:
			var sched: Array = []
			for w in n.get("when", []):
				if String(w.get("flag", "")) == flag: sched = w.schedule
			var at_hall: Array = sched.filter(func(e): return int(e[0]) <= 20 and int(e[1]) >= 22 and String(e[3]) == "dance")
			if flag == "river_town_hall_ready" and not at_hall.is_empty(): dancers += 1
			for e in at_hall:
				var p: Array = nodes.get(String(e[2]), [])
				t.ok(String(e[2]).begins_with("river_town_dance_hall") or (p.size() == 2 and hall.has_point(Vector2(float(p[0]), float(p[1])))), "%s dances in the hall (%s)" % [n.id, e[2]])
	t.ok(dancers >= 8, "%d villagers dance from 8 to 10 every evening once the hall is ready" % dancers)
	var c := Chibi.new({})
	c.play("dance", true)
	var turns: Array = []
	for k in 30:
		c.animate(0.1, 0.0)
		turns.append(c.body.rotation.y)
	t.ok(c.hold == "dance" and turns.max() - turns.min() > 0.5, "a dancer sways and turns (%.2f)" % (turns.max() - turns.min()))
	c.free()
