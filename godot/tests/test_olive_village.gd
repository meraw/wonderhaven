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
