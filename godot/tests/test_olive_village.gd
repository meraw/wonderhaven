extends RefCounted
var t
const OV := preload("../scripts/locations/olive_village.gd")
const ID := "olive_village"
const STEP := 0.5

func _on(fn: Callable) -> void:
	Data.use_island(ID)
	fn.call()
	Data.use_island("hearthglow")

func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x / STEP), roundi(z / STEP))

func _reach(floors: bool, targets: Array) -> Dictionary:
	var w := WalkWorld.new([])
	if floors: w.floors = WorldStatics.floors()
	var sp: Dictionary = Data.layout.spawn
	var c0 := _cell(sp.x, sp.z)
	var y0 := Heightfield.height(sp.x, sp.z)
	var start := Vector3i(c0.x, c0.y, roundi(y0 * 2.0))
	var seen := {start: y0}
	var open := [start]
	var far := 0.0
	var found := {}
	while not open.is_empty():
		var c: Vector3i = open.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = c.x + dv.x
			var nz: int = c.y + dv.y
			if absi(nx) > 184 or absi(nz) > 184: continue
			var x := nx * STEP
			var z := nz * STEP
			var s := w.can_stand(x, z, seen[c], 0.0)
			if s.is_empty(): continue
			var key := Vector3i(nx, nz, roundi(float(s.y) * 2.0))
			if seen.has(key): continue
			seen[key] = s.y
			far = maxf(far, maxf(absf(x), absf(z)))
			if targets.has(Vector2i(nx, nz)): found[Vector2i(nx, nz)] = true
			open.append(key)
	return {"far": far, "found": found}

func _walks(w: WalkWorld, a: Array, b: Array) -> bool:
	var from := Vector2(a[0], a[1])
	var to := Vector2(b[0], b[1])
	var feet := maxf(Heightfield.height(from.x, from.y), WorldStatics.floor_top(from.x, from.y))
	var n := int(ceil(from.distance_to(to) / 0.1))
	for i in range(1, n + 1):
		var p := from.lerp(to, float(i) / n)
		var s := w.can_stand(p.x, p.y, feet, 0.3)
		if s.is_empty(): return false
		feet = s.y
	return true

func test_the_pack_is_loaded():
	t.ok(Data.location_ids().has(ID), "Liolivato is a location pack")
	var d := Data.island_def(ID)
	t.eq(d.get("name", ""), "Liolivato", "its map entry is named")
	t.ok(d.get("reveal", "") == "olive_village_revealed" and not Travel.on_map(d, {}, "hearthglow"), "it stays off the travel map until Serenza's finale reveals it")
	t.ok(Travel.on_map(d, {"olive_village_revealed": true}, "hearthglow"), "and turns up once it does")
	t.ok(not WorkDay.holds(d.get("day", {})), "the clock never holds at dusk here")
	t.eq(LocationMeter.reading(d.get("meter", {}), 0), "38 inhabitants", "the population sign starts at 38")
	t.eq(LocationMeter.reading(d.get("meter", {}), 12), "50 inhabitants", "and reads 50 with everything done")
	t.ok(d.get("look", {}).has("light"), "it has its own look")
	t.ok(Data.read_layout(ID).features.any(func(f): return f.kind == "boat" and f.get("depart_label", "") == "Take the ferry"), "you leave by the ferry from the jetty")

func test_ground_shape():
	_on(func():
		var H := func(x: float, z: float) -> float: return Heightfield.height(x, z)
		t.ok(Heightfield.is_water(0, 80) and Heightfield.is_water(60, 75) and Heightfield.is_water(-60, 72), "the sea lies along the south")
		var tc: float = OV.torrent_center(-20.0)
		t.ok(Heightfield.is_water(tc, -20.0) and Heightfield.is_stream_cell(floorf(tc), -21), "the torrent runs down the middle, flowing")
		t.ok(not Heightfield.is_stream_cell(20, 75) and not Heightfield.is_stream_cell(OV.GULLY_E, 0), "the sea and the gullies don't turn a waterwheel")
		t.ok(H.call(OV.BRIDGE_W - 0.5, OV.BRIDGE_Z) - Heightfield.WATER_Y > 7.0, "the bridge crosses a deep gorge")
		t.ok(H.call(-44, -61) > H.call(-20, -6) + 8.0 and H.call(-20, -6) > H.call(-1.5, 12) + 4.0, "the village climbs the spur from the bridge to the castle")
		t.ok(H.call(40, -70) > H.call(40, 0) + 10.0 and H.call(40, 0) > H.call(30, 52) + 6.0, "the east bank climbs from the cove to the woods")
		var treads := {}
		for k in 40: treads[snappedf(H.call(60.0, 30.0 - k * 1.5), 0.01)] = true
		t.ok(treads.size() >= 6 and treads.size() <= 14, "the terraces are level treads stepping up the slope (%d levels)" % treads.size())
		t.ok(H.call(-20, -86) > H.call(-20, -80) + 3.0, "a crag runs along the north")
		t.ok(Heightfield.is_water(OV.GULLY_W, 0) and Heightfield.is_water(OV.GULLY_E, -40), "gullies run down the west and east edges")
		t.ok(absf(H.call(-20, -6) - OV.PIAZZA.y) < 0.01, "the piazza is level")
		t.eq(Ground.kind_at(-20, -6), "setts", "and paved")
		var boathouse: Dictionary = Data.layout.buildings.filter(func(b): return b.id == "olive_village_boathouse")[0]
		t.ok(boathouse.x > OV.torrent_center(boathouse.z), "the fishing cove is on the terraces' bank"))

func test_the_bridge_joins_the_banks():
	_on(func():
		var piazza := _cell(-20, -6)
		var castle := _cell(-43, -58)
		var fuco := _cell(37, -62)
		var farm := _cell(33, 1)
		var r := _reach(true, [piazza, castle, fuco, farm])
		t.ok(r.far < 88.0, "the sea, the gullies and the crag keep you on the map (furthest %.1f m)" % r.far)
		t.ok(r.found.has(piazza) and r.found.has(castle), "from the cove you can walk up to the piazza and the castle")
		t.ok(r.found.has(fuco) and r.found.has(farm), "and up the terraces to Bastian's farmhouse and Fuco's hut")
		var wet := true
		for z in range(-90, 62): wet = wet and Heightfield.is_water(OV.torrent_center(z), z)
		t.ok(wet, "the torrent is water all the way from the crag to the sea, so the bridge is the only way across"))

func test_every_nav_edge_can_be_walked():
	_on(func():
		var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
		var w := WalkWorld.new(statics, func(_f): return true)
		w.floors = WorldStatics.floors()
		for e in Data.layout.nav_edges:
			if e.size() > 2: continue
			var a: Array = Data.layout.nav_nodes[e[0]]
			var b: Array = Data.layout.nav_nodes[e[1]]
			t.ok(_walks(w, a, b) and _walks(w, b, a), "you can walk %s to %s and back" % [e[0], e[1]])
		for k in Data.layout.nav_nodes:
			t.ok(not Schedule.find_path("beach", k, {}).is_empty(), "the nav graph reaches %s from the beach" % k))

func test_buildings_stand_on_level_ground():
	_on(func():
		for b in Data.layout.buildings:
			var c := Heightfield.height(b.x, b.z)
			var worst := 0.0
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					worst = maxf(worst, absf(Heightfield.height(b.x + dx * b.w / 2.0, b.z + dz * b.d / 2.0) - c))
			t.ok(worst < 0.15, "%s stands on level ground (%.2f m)" % [b.id, worst]))

func test_build_sites_fit_their_jobs():
	_on(func():
		var jetty := Data.zone("olive_village_jetty")
		var a: Dictionary = jetty.endpoints.a
		var b: Dictionary = jetty.endpoints.b
		t.ok(not Heightfield.is_water(a.minI + 2.5, a.minK + 0.5) and Heightfield.is_water(b.minI + 2.5, b.minK + 0.5), "the jetty runs from the pebbles out into the sea")
		var works := Data.zone("olive_village_works")
		var flowing := 0
		for i in range(works.minI, works.maxI + 1):
			for k in range(works.minK, works.maxK + 1):
				if Heightfield.is_stream_cell(i, k): flowing += 1
		t.ok(flowing >= 6, "the site below the bridge reaches flowing water (%d cells)" % flowing)
		var beside := false
		for k in range(18, 28):
			if Heightfield.is_stream_cell(9, k) and absf(BuildGrid.ground_at(10, k) - OV.SHELF_H) < 0.01: beside = true
		t.ok(beside, "the shelf runs level to the water's edge, so a pump there sits beside a waterwheel")
		var tank: Dictionary = Data.layout.machines[0]
		t.ok(BuildGrid.zone_contains(works, tank.cell[0], tank.cell[1], 999), "the tank's inlet is on the site")
		var climb := true
		for k in range(27, 40): climb = climb and absf(BuildGrid.ground_at(12, k + 1) - BuildGrid.ground_at(12, k)) <= 0.7
		t.ok(climb, "pipes can climb the ramp from the shelf to the tank, cell by cell")
		var w := WalkWorld.new([])
		w.floors = WorldStatics.floors()
		t.ok(not Validate.path_across(Data.zone("olive_village_steps"), w).get("ok", false), "a flight of the mule track has collapsed: Gambero's steps can't be climbed")
		var pit := OV.pit_level()
		var below := Heightfield.height(20.5, OV.MULE_GAP.y + 0.2) - pit
		var above := Heightfield.height(20.2, OV.MULE_GAP.x - 0.2) - pit
		t.ok(below > WalkWorld.STEP_UP and below < 1.25 and above > 1.4, "fall into the gap and you can jump out on the downhill side (%.2f m), never up the uphill one (%.2f m)" % [below, above])
		t.ok(Validate.path_across(Data.zone("olive_village_wall"), w).get("ok", false), "the fallen terrace's wall has come down into a slope of rubble")
		t.ok(not _walks(w, [30.0, -12.0], [30.0, -22.0]), "beside the gap the terrace wall still stands")
		for id in ["olive_village_house", "olive_village_sunset", "olive_village_plot", "olive_village_hives"]:
			var zn := Data.zone(id)
			var lo := INF
			var hi := -INF
			for i in range(zn.minI, zn.maxI + 1):
				for k in range(zn.minK, zn.maxK + 1):
					lo = minf(lo, BuildGrid.ground_at(i, k))
					hi = maxf(hi, BuildGrid.ground_at(i, k))
			t.ok(hi - lo < 0.2, "%s is level ground to build on (%.2f m)" % [id, hi - lo]))

func test_rooms_you_can_walk_into():
	_on(func():
		var rooms := ["olive_village_osteria", "olive_village_barber", "olive_village_sandals", "olive_village_church",
			"olive_village_farmhouse", "olive_village_boathouse", "olive_village_empty_house"]
		for id in rooms:
			var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == id)[0]
			t.ok(Interiors.enterable(b), "%s is a room you can walk into" % id)
			t.ok(Data.layout.nav_nodes.has(String(b.get("navDoor", ""))), "%s has a spot outside its door" % id)
			t.ok(not Schedule.find_path("beach", id + ":spot", {}).is_empty(), "you can walk from the beach into %s" % id)
		var empty: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "olive_village_empty_house")[0]
		t.ok(empty.interior.get("empty", false) and empty.interior.items.is_empty(), "the empty house beside the osteria waits, bare, for the finale"))

func test_landmarks_and_trees():
	_on(func():
		var by_id := {}
		for b in Data.layout.buildings: by_id[b.id] = b
		var tallest := 0.0
		for b in Data.layout.buildings:
			if b.id != "olive_village_belltower": tallest = maxf(tallest, float(b.get("h", 0.0)))
		t.ok(float(by_id["olive_village_belltower"].h) > tallest, "the church's tiled spire rises above every roof")
		t.ok(not by_id["olive_village_washhouse"].get("solid", true), "the wash-house is open-sided")
		var statics := WorldStatics.build_statics(WorldStatics.generate_decor())
		var w := WalkWorld.new(statics, func(_f): return true)
		var wash: Dictionary = by_id["olive_village_washhouse"]
		t.ok(w.blocked(wash.x, wash.z, Heightfield.height(wash.x, wash.z), 0.3), "its stone basin is solid")
		t.ok(not w.blocked(wash.x + 1.0, wash.z + 1.2, Heightfield.height(wash.x + 1.0, wash.z + 1.2), 0.3), "but you can walk in under its roof")
		var trees: Array = Data.layout.props.filter(func(p): return p.kind == "olive_village_tree")
		t.ok(trees.filter(func(p): return p.tree == "olive").size() >= 80, "olive trees stand in rows on the terraces (%d)" % trees.size())
		var level := true
		var dry := true
		var off_sites := true
		for p in trees:
			var h := Heightfield.height(p.x, p.z)
			dry = dry and h > 0.4
			if p.x > OV.torrent_center(p.z):
				for o in [Vector2(0.6, 0.0), Vector2(-0.6, 0.0), Vector2(0.0, 0.6), Vector2(0.0, -0.6)]:
					level = level and absf(Heightfield.height(p.x + o.x, p.z + o.y) - h) < 0.05
			for zn in Data.layout.zones:
				if BuildGrid.zone_contains(zn, floorf(p.x), floorf(p.z), 999): off_sites = false
		t.ok(dry and level, "every tree is on dry land, and on the terraces it stands on a level tread, clear of the walls")
		t.ok(off_sites, "no tree stands on a build site")
		t.ok(Data.layout.props.filter(func(p): return p.kind == "olive_village_arch").size() == 3, "three covered passages arch over the alley from the bridge to the piazza"))

func _pl(id: String, i: int, k: int, uid: int, y = null) -> Dictionary:
	return {"id": id, "i": i, "k": k, "r": 0, "y": BuildGrid.ground_at(i, k) if y == null else float(y), "uid": uid}

func test_shared_a_path_can_be_made_of_given_pieces():
	_on(func():
		var zone := {"minI": -24, "maxI": -20, "minK": 17, "maxK": 17,
			"endpoints": {"a": {"minI": -24, "maxI": -24, "minK": 17, "maxK": 17}, "b": {"minI": -20, "maxI": -20, "minK": 17, "maxK": 17}}}
		var w := WalkWorld.new([])
		t.ok(Validate.path_across(zone, w).ok, "the bare ground can be walked from one end to the other")
		var gap := {Vector2i(-24, 17): true, Vector2i(-23, 17): true, Vector2i(-21, 17): true, Vector2i(-20, 17): true}
		t.ok(not Validate.path_across(zone, w, gap).ok, "but not on the given cells when one is missing")
		gap[Vector2i(-22, 17)] = true
		t.ok(Validate.path_across(zone, w, gap).ok, "and it can once the gap is filled")
		var ctx := {"path": func(_zid, only): return Validate.path_across(zone, w, only)}
		var tiles: Array = []
		for i in [-24, -23, -21, -20]: tiles.append(_pl("gardenPath", i, 17, 100 + i))
		var c := {"check": "path", "zone": "zz", "on": ["gardenPath"]}
		ctx["placements"] = []
		t.ok(not Commission.check(c, {}, [], ctx).ok, "with none of the paving pieces down at all, it fails too (it doesn't fall back to the bare ground)")
		ctx["placements"] = tiles
		t.ok(not Commission.check(c, {}, tiles, ctx).ok, "a commission's path of paving pieces fails with a tile missing")
		tiles.append(_pl("gardenPath", -22, 17, 200))
		ctx["placements"] = tiles
		t.ok(Commission.check(c, {}, tiles, ctx).ok, "and passes when the paving runs end to end"))

func test_shared_a_view_check_sees_past_open_ground_but_not_walls():
	_on(func():
		var seat := _pl("bench", -17, 17, 1)
		var sea := Vector2(-16.5, 80.0)
		t.ok(Commission.sees(seat, sea, [seat], 40.0), "from the Sandals' terrace a seat looks out to sea")
		var wall := _pl("woodWall", -17, 19, 2)
		t.ok(not Commission.sees(seat, sea, [seat, wall], 40.0), "a wall in front of the seat hides the sea")
		var high := _pl("woodWall", -17, 19, 3, BuildGrid.ground_at(-17, 17) + 2.6)
		t.ok(Commission.sees(seat, sea, [seat, high], 40.0), "something above eye height, like a pergola's roof, doesn't")
		var behind := _pl("bench", -17, 7, 4)
		t.ok(not Commission.sees(behind, sea, [behind], 40.0), "the Sandals' house stands between a seat behind it and the sea")
		var c := {"check": "view", "of": ["bench"], "to": [sea.x, sea.y]}
		t.ok(Commission.check(c, {}, [seat], {"placements": [seat]}).ok, "a view check passes for a seat with the sea in view")
		t.ok(not Commission.check(c, {}, [seat, wall], {"placements": [seat, wall]}).ok, "and fails when it's walled in"))

func test_shared_the_petal_carpet_and_the_beehive():
	var carpet := Data.piece("petalCarpet")
	var hive := Data.piece("beehive")
	t.ok(carpet.get("walkable", false) and not carpet.get("solid", true) and carpet.get("colorable", false), "the petal carpet is a flat tile you walk on, in any colour")
	t.ok(int(carpet.get("cost", {}).get("flowers", 0)) > 0, "it's laid with the flowers you gather")
	t.ok(hive.get("solid", true) and int(hive.get("cost", {}).get("wood", 0)) > 0, "the beehive is a solid wooden box")
	for id in ["petalCarpet", "beehive"]:
		var mesh := PieceMeshes.make(id)
		t.ok(mesh.get_child_count() > 0, "%s has a model" % id)
		mesh.free()

func _people() -> Array:
	return Data.npcs.filter(func(n): return Data.npc_island(String(n.id)) == ID)

func test_people_and_their_days():
	_on(func():
		var people := _people()
		t.eq(people.size(), 14, "ten villagers live in Liolivato, and Davide's family of four comes at the festa")
		var visitors: Array = people.filter(func(n): return n.has("present"))
		t.ok(visitors.size() == 4 and visitors.all(func(n): return n.present == "olive_village_festa_night"), "the family is only there from the festa night on")
		var sp: Dictionary = Data.layout.spawn
		for n in people:
			t.ok(Data.layout.nav_nodes.has(n.home), "%s has a home here (%s)" % [n.id, n.home])
			t.ok(Chibi.sanitize(n.appearance).skin == n.appearance.skin and Chibi.sanitize(n.appearance).top == n.appearance.top, "%s keeps the colours and clothes written for them" % n.id)
			var days: Array = [n.schedule]
			for w in n.get("when", []): days.append(w.schedule)
			for d in days:
				for e in d:
					t.ok(Data.layout.nav_nodes.has(e[2]), "%s's day takes them to a real spot (%s)" % [n.id, e[2]])
					var at_spot: Array = Data.layout.nav_nodes.get(e[2], [0, 0])
					t.ok(Vector2(at_spot[0] - sp.x, at_spot[1] - sp.z).length() > 1.5, "%s never stands where the ferry leaves you (%s)" % [n.id, e[2]])
					t.ok(not Schedule.find_path("beach", e[2], {}).is_empty(), "%s can walk to %s" % [n.id, e[2]])
		var at := func(npc: String, hour: float, flags: Dictionary) -> Dictionary: return Schedule.activity_at(Data.npc("olive_village_" + npc), hour * 60.0, flags)
		var w := {"olive_village_tour": true, "olive_village_welcomed": true}
		t.eq(at.call("giobatta", 23.0, {}).node, "pebbles", "the Sindaco waits on the pebbles for the new Geometra, at any hour")
		t.eq(at.call("giobatta", 23.0, {"olive_village_tour": true}).node, "olive_village_barber:spot", "then in the barber shop with the papers")
		t.eq(at.call("giobatta", 7.5, w).node, "churchDoor", "once you're settled he rings the bells in the morning")
		t.eq(at.call("giacomo", 16.0, w).node, "olive_village_osteria:in", "Gambero plays cards at the osteria in the afternoon")
		t.eq(at.call("ilario", 7.0, w).activity, "work", "Fuco is up with his bees at dawn, for the swarm")
		var ready: Dictionary = w.duplicate(); ready["olive_village_festa_ready"] = true
		t.eq(at.call("giobatta", 21.0, ready).node, "piazza", "on the festa's evening the Sindaco waits on the piazza for the band")
		var night: Dictionary = ready.duplicate(); night["olive_village_festa_night"] = true
		var piazza := ["piazza", "piazzaN", "piazzaS", "piazzaE", "piazzaW", "piazzaNW", "piazzaNE", "piazzaSW", "piazzaSE"]
		var dancing := people.filter(func(n): return piazza.has(String(at.call(String(n.id).trim_prefix("olive_village_"), 21.0, night).node))).size()
		t.ok(dancing >= 9, "after the festa the village comes to the piazza in the evening (%d)" % dancing)
		var carpet: Dictionary = {}
		for o in Data.quest("olive_village_festa").objectives:
			for e in o.get("plan", []):
				if String(e[2]) == "petalCarpet": carpet[Vector2i(int(e[0]), int(e[1]))] = true
		for n in people:
			var days: Array = [n.schedule]
			for wd in n.get("when", []): days.append(wd.schedule)
			for d in days:
				for e in d:
					var sp2: Array = Data.layout.nav_nodes[e[2]]
					t.ok(float(e[1]) - float(e[0]) < 2.0 or not carpet.has(Vector2i(floori(sp2[0]), floori(sp2[1]))), "%s doesn't spend hours standing on the petal carpet's way (%s)" % [n.id, e[2]])
		for flags in [{}, {"olive_village_tour": true}, w, {"olive_village_tour": true, "olive_village_welcomed": true, "olive_village_water_done": true}, ready, night]:
			for h in 24:
				var taken := {}
				for n in people:
					if n.has("present") and not flags.get(n.present, false): continue
					var spot: String = at.call(String(n.id).trim_prefix("olive_village_"), h + 0.5, flags).node
					t.ok(not taken.has(spot), "%s and %s don't share %s at %d:30" % [taken.get(spot, ""), n.id, spot, h])
					taken[spot] = n.id)

func test_requests_and_the_sign():
	_on(func():
		var mine: Array = Data.quests.filter(func(q): return Data.quest_island(String(q.id)) == ID)
		t.eq(mine.size(), 17, "six main requests, three side requests and eight lost things")
		var main: Array = mine.filter(func(q): return q.get("main", false))
		var lost: Array = mine.filter(func(q): return String(q.id).contains("_lost_"))
		t.eq(main.size(), 6, "six of them tell the main story")
		t.eq(lost.size(), 8, "eight are lost things")
		var total := 0
		var without := 0
		for q in mine:
			var want := 0 if lost.has(q) else (4 if q.id == "olive_village_festa" else 1)
			t.eq(int(q.rewards.get("meter", 0)), want, "%s brings %d to the sign" % [q.id, want])
			total += int(q.rewards.get("meter", 0))
			if q.get("main", false): without += int(q.rewards.get("meter", 0))
		var m: Dictionary = LocationMeter.def(ID)
		t.eq(LocationMeter.reading(m, total), "50 inhabitants", "everything together brings the sign to 50")
		t.eq(LocationMeter.reading(m, without), "47 inhabitants", "without the side requests it stops at 47")
		var by_at := {}
		for u in m.milestones: by_at[int(u.at)] = u
		t.ok(by_at[2].flags.has("olive_village_plot"), "at 40 a strip of terrace is yours")
		t.ok(by_at[5].blueprints.has("beehive") and by_at[5].flags.has("olive_village_hive_plans"), "at 43 the beehive plans, so Fuco can ask about his swarm")
		t.ok(by_at[8].flags.has("olive_village_own_olive"), "at 46 an olive tree of your own")
		t.ok(by_at[12].requires.quests.has("olive_village_festa") and by_at[12].flags.has("olive_village_free_haircut"), "at 50 the honours, which wait for the festa")
		var all := {}
		for f in OV.SIGN: all[f] = true
		t.eq(OV.sign_points(all), total, "the sign by the bridge counts the same as the meter")
		var done := {}
		for q in mine:
			for f in q.rewards.get("flags", []): done[f] = true
		t.eq(OV.sign_points(done), total, "and every request that counts sets the flag the sign reads")
		Data.apply_world_flags({"olive_village_welcomed": true})
		var sign: Array = Data.layout.features.filter(func(f): return f.id == "olive_village_sign")
		t.eq(String(sign[0].text), "Liolivato. 39 inhabitants.", "signing for your house makes it 39, on the sign")
		Data.apply_world_flags({})
		t.eq(String(Data.layout.features.filter(func(f): return f.id == "olive_village_sign")[0].text), "Liolivato. 38 inhabitants.", "before that it reads 38")
		var festa: Dictionary = Data.quest("olive_village_festa")
		for id in ["olive_village_jetty", "olive_village_water", "olive_village_terrace", "olive_village_roof"]:
			t.ok(festa.requires.quests.has(id), "the festa waits for %s" % id)
		t.ok(Data.quest("olive_village_swarm").requires.flags.has("olive_village_hive_plans"), "Fuco asks about his swarm once you have the beehive plans")
		var people: Array = _people().map(func(n): return String(n.id))
		for q in mine:
			t.ok(people.has(String(q.giver)), "%s is given by someone who lives here" % q.id)
			for o in q.objectives:
				if o.has("npc"): t.ok(people.has(String(o.npc)), "%s: %s is someone who lives here" % [q.id, o.npc])
				if o.kind == "gather" and String(o.item).begins_with("olive_village_"):
					t.ok(Data.layout.nodes.any(func(n): return n.get("gives", {}).has(o.item) or (n.kind == "forage" and n.get("item", "") == o.item)), "%s: something in Liolivato gives %s" % [q.id, o.item])
				if o.kind == "commission": t.ok(not Data.zone(String(o.zone)).is_empty(), "%s builds on a real site (%s)" % [q.id, o.zone])
		var swarm: Dictionary = Data.node_def("olive_village_swarm")
		t.ok(swarm.hours.map(func(h): return int(h)) == [5, 9] and swarm.flag == "olive_village_swarm_ready", "the swarm can only be fetched at dawn, once Fuco has handed you the box")
		t.ok(Data.quest("olive_village_swarm").objectives.any(func(o): return o.get("onDone", {}).get("flags", []).has("olive_village_swarm_ready")), "and he hands it over in the request")
		for q in lost:
			var key := String(q.id).trim_prefix("olive_village_lost_")
			var node := Data.node_def("olive_village_lost_" + key)
			t.ok(node.kind == "fragment" and node.get("once", false) and node.gives.has("olive_village_" + key), "%s lies somewhere to be found once" % key)
			t.ok(q.onAccept.flags.has(String(node.flag)), "and turns up once %s has asked about it" % q.giver)
		var near := func(n: Dictionary) -> Array:
			var cells: Array = [_cell(n.x, n.z)]
			if n.kind == "fish":
				for dx in range(-4, 5):
					for dz in range(-4, 5): cells.append(_cell(n.x + dx * STEP, n.z + dz * STEP))
			return cells
		var targets: Array = []
		for n in Data.layout.nodes: targets.append_array(near.call(n))
		var r := _reach(true, targets)
		for n in Data.layout.nodes: t.ok(near.call(n).any(func(c): return r.found.has(c)), "%s can be reached on foot (a fishing spot from the shore beside it)" % n.id))

func test_tastes_and_shops():
	_on(func():
		var villagers: Array = _people().filter(func(n): return not n.has("present"))
		for n in villagers:
			var tt := Tastes.of(String(n.id))
			t.ok(not tt.is_empty() and Tastes.near_pos(String(n.id)) != Vector2.INF, "%s has tastes and a spot" % n.id)
			for p in tt.get("pieces", []): t.ok(not Data.piece(String(p)).is_empty(), "%s likes a real piece (%s)" % [n.id, p])
			for c in tt.get("colours", []):
				t.ok(Data.palette.any(func(pc): return Color(String(pc)).is_equal_approx(Color(String(c)))), "%s likes a colour you can paint (%s)" % [n.id, c])
		t.eq(Tastes.here().size(), villagers.size(), "in Liolivato only its own villagers' tastes count")
		var mine: Array = Data.shops.shops.keys().filter(func(id): return String(id).begins_with("olive_village_"))
		t.eq(mine.size(), 4, "four shops: Rosa's osteria, the Sindaco's everything shop, Fuco's honey and Gambero's nets")
		var rosa: Dictionary = Shop.def("olive_village_rosa")
		t.ok(rosa.buys.has("olive_village_basil") and rosa.buys.has("olive_village_mullet"), "Rosa buys basil for her pesto, and fish")
		t.ok(Shop.def("olive_village_giobatta").stock.any(func(l): return l.get("items", {}).has("clay")), "there's no clay here: the Sindaco sells it"))

func test_the_rebuilt_terrace_can_be_climbed():
	_on(func():
		var o: Dictionary = Data.quest("olive_village_terrace").objectives.filter(func(x): return x.has("plan"))[0]
		var built: Array = []
		for pl in Plans.lay_out(o.plan, Data.zone(String(o.zone)), []):
			pl.uid = built.size() + 1
			built.append(pl)
		var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return false)
		w.floors = WorldStatics.floors()
		w.surfaces = BuildGrid.surfaces_for(built)
		var climb := {"minI": 38, "maxI": 42, "minK": -22, "maxK": -14,
			"endpoints": {"a": {"minI": 38, "maxI": 42, "minK": -14, "maxK": -14}, "b": {"minI": 38, "maxI": 42, "minK": -21, "maxK": -21}}}
		t.ok(Validate.sealed(Data.zone("olive_village_wall"), built).sealed, "the rebuilt wall closes the gap")
		t.ok(Validate.path_across(climb, w).ok, "and its stairs take you up from the rubble onto the terrace")
		var foot: Array = Data.layout.nav_nodes.fallenStair
		var top: Array = Data.layout.nav_nodes.fallenTop
		t.ok(_walks(w, foot, top) and _walks(w, top, foot), "straight up the stairs from the spot below to the spot on top, and back"))

func test_the_rebuilt_flight_carries_the_mule_track():
	_on(func():
		var o: Dictionary = Data.quest("olive_village_steps").objectives.filter(func(x): return x.has("plan"))[0]
		var built: Array = []
		for pl in Plans.lay_out(o.plan, Data.zone(String(o.zone)), []):
			pl.uid = built.size() + 1
			built.append(pl)
		var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
		w.floors = WorldStatics.floors()
		var a: Array = Data.layout.nav_nodes.mule1
		var b: Array = Data.layout.nav_nodes.mule2
		t.ok(not _walks(w, a, b), "before it's rebuilt you can't walk up the mule track")
		w.surfaces = BuildGrid.surfaces_for(built)
		t.ok(_walks(w, a, b) and _walks(w, b, a), "once it is, the straight way between the spots either side runs over it, both ways"))

