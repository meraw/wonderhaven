extends RefCounted
var t

const Port := preload("../scripts/locations/port.gd")
const EARLIER := ["hearthglow", "river_town", "rice_village", "metropolis"]

func _on(fn: Callable) -> void:
	Data.use_island("port")
	fn.call()
	Data.use_island("hearthglow")

func _walker() -> WalkWorld:
	var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return false)
	w.floors = WorldStatics.floors()
	return w

func _walk(w: WalkWorld, from: Vector2, to: Vector2) -> Dictionary:
	var feet: float = w.surface_at(from.x, from.y).y
	var n := maxi(1, int(ceil(from.distance_to(to) / 0.12)))
	for i in range(1, n + 1):
		var p := from.lerp(to, float(i) / n)
		var s := w.can_stand(p.x, p.y, feet, 0.3)
		if s.is_empty(): return {"ok": false, "at": p, "y": feet}
		feet = s.y
	return {"ok": true, "at": to, "y": feet}

func _node(id: String) -> Vector2:
	var p: Array = Data.layout.nav_nodes[id]
	return Vector2(p[0], p[1])

func _layout() -> Dictionary: return Data.read_layout("port")

func test_tonnarella_is_a_location_pack():
	t.ok(Data.location_ids().has("port"), "the port pack is loaded")
	var def := Data.island_def("port")
	t.eq(def.get("name", ""), "Tonnarella", "its name on the travel map")
	t.eq(def.get("reveal", ""), "metropolis_angel_lit", "it turns up when Toriano's angel is lit")
	t.eq(def.get("bikes", true), false, "no bicycles on the stairs")
	t.ok(not Travel.on_map(def, {}, "hearthglow"), "it isn't on a new game's map")
	t.ok(Travel.on_map(def, {"metropolis_angel_lit": true}, "metropolis"), "Toriano's finale puts it on the map")
	_on(func(): t.ok(Data.layout.features.any(func(f): return f.kind == "boat" and f.get("depart_label", "") == "Take the train"), "you leave by train"))

func test_every_id_starts_with_port():
	var L := _layout()
	for list in ["buildings", "zones", "nodes", "features", "port_lift_stops", "floors"]:
		for e in L.get(list, []): t.ok(String(e.id).begins_with("port_"), "%s: %s" % [list, e.id])
	for k in L.nav_nodes: t.ok(String(k).begins_with("port_"), "nav node %s" % k)

func test_three_levels_and_the_sea():
	_on(func():
		t.eq(Heightfield.height(-8.0, -58.0), Port.TOP_H, "the station forecourt is on top")
		t.eq(Heightfield.height(2.0, -6.0), Port.MID_H, "the church square is halfway up")
		t.eq(Heightfield.height(0.0, 30.0), Port.QUAY_H, "the quays are at the harbour")
		t.ok(Heightfield.is_water(0.0, 60.0), "the harbour is water")
		t.ok(Heightfield.is_water(-80.0, -20.0), "the bay is water")
		t.ok(Heightfield.is_water(90.0, 0.0), "the open sea is water")
		t.ok(Heightfield.height(0.0, -100.0) > Port.TOP_H + 4.0, "the mountain rises behind the station")
		t.ok(Heightfield.height(64.0, -10.0) > Heightfield.WALKABLE_MIN and Heightfield.height(64.0, -10.0) < 2.0, "the east rocks lie low by the sea")
		t.ok(Heightfield.height(42.0, 78.0) > Heightfield.WALKABLE_MIN, "the lighthouse rock is dry"))

func test_every_path_can_be_walked_both_ways():
	_on(func():
		var w := _walker()
		for e in Data.layout.nav_edges:
			if e.size() > 2: continue
			var a := _node(e[0]); var b := _node(e[1])
			var there := _walk(w, a, b)
			t.ok(there.ok, "walk %s to %s (stopped at %s)" % [e[0], e[1], str(there.at)])
			var back := _walk(w, b, a)
			t.ok(back.ok, "walk %s to %s (stopped at %s)" % [e[1], e[0], str(back.at)]))

func test_every_level_is_reached_from_the_station():
	_on(func():
		var seen := {"port_station": true}
		var todo := ["port_station"]
		while not todo.is_empty():
			var at: String = todo.pop_back()
			for e in Data.layout.nav_edges:
				if e.size() > 2: continue
				for pair in [[e[0], e[1]], [e[1], e[0]]]:
					if pair[0] == at and not seen.has(pair[1]):
						seen[pair[1]] = true
						todo.append(pair[1])
		for id in ["port_belvedere", "port_castle_gate", "port_square", "port_church_door", "port_nonna_door", "port_home_door", "port_court", "port_bakery_door", "port_bank_door", "port_chandlery_door", "port_harbour_office_door", "port_fishmarket", "port_breakwater_n", "port_rocks_n", "port_lift_bottom"]:
			t.ok(seen.has(id), "you can walk from the station to %s" % id)
		for id in ["port_breakwater_s", "port_rock", "port_lighthouse_door"]:
			t.ok(not seen.has(id), "%s waits for the breakwater" % id)
		var levels := {}
		for id in seen: levels[Port.level(_node(id).x, _node(id).y)] = true
		for lv in ["top", "middle", "quay", "rocks", "breakwater"]: t.ok(levels.has(lv), "the walk reaches the %s" % lv))

func test_the_stair_lanes_are_the_way_between_levels():
	_on(func():
		var w := _walker()
		t.ok(_walk(w, Vector2(-11.0, 0.0), Vector2(-11.0, 30.0)).ok, "down the lane by the bakery")
		t.ok(_walk(w, Vector2(6.0, 2.0), Vector2(6.0, 30.0)).ok, "down the lane from the church square")
		t.ok(_walk(w, Vector2(16.0, -20.0), Vector2(16.0, -38.0)).ok, "up the lane to the castle")
		for x in [-38.0, -20.0, 0.0, 14.0, 25.0, 36.0, 52.0]:
			var r := _walk(w, Vector2(x, 0.0), Vector2(x, 30.0))
			t.ok(not r.ok and r.y > Port.MID_H - 0.5, "no way down to the quay at x = %s but the lanes" % x)
		for x in [-38.0, -21.0, 2.0, 27.0, 46.0]:
			var r := _walk(w, Vector2(x, -36.0), Vector2(x, 0.0))
			t.ok(not r.ok and r.y > Port.TOP_H - 0.5, "no way down from the top at x = %s but the lanes" % x))

func test_cliffs_stop_you_at_the_edge():
	_on(func():
		var w := _walker()
		var west := _walk(w, Vector2(-40.0, 0.0), Vector2(-52.0, 0.0))
		t.ok(not west.ok and west.y == Port.MID_H, "the alleys end above the bay")
		var east := _walk(w, Vector2(50.0, 0.0), Vector2(66.0, 0.0))
		t.ok(not east.ok and east.y == Port.MID_H, "a parapet at the end of the main alley")
		var castle := _walk(w, Vector2(50.0, -40.0), Vector2(66.0, -40.0))
		t.ok(not castle.ok and castle.y == Port.TOP_H, "a parapet by the castle")
		var belvedere := _walk(w, Vector2(-30.0, -42.0), Vector2(-56.0, -42.0))
		t.ok(not belvedere.ok and belvedere.y == Port.TOP_H, "the belvedere ends above the bay")
		var up := _walk(w, Vector2(64.0, -20.0), Vector2(50.0, -20.0))
		t.ok(not up.ok and up.y < 2.0, "the east rocks don't climb the cliff")
		var quay := _walk(w, Vector2(0.0, 38.0), Vector2(0.0, 50.0))
		t.ok(not quay.ok and quay.y == Port.QUAY_H, "the quay ends at the harbour"))

func test_the_lighthouse_waits_for_the_breakwater():
	_on(func():
		var w := _walker()
		var r := _walk(w, _node("port_breakwater_root"), _node("port_rock"))
		t.ok(not r.ok and r.at.y < Port.GAP_Z.x + 0.5, "the walk out stops at the gap (%s)" % str(r.at))
		t.ok(Heightfield.is_water(39.5, 57.0), "the gap is open water")
		var gated: Array = Data.layout.nav_edges.filter(func(e): return e.size() > 2)
		t.eq(gated.size(), 1, "one path waits for a flag")
		t.eq(gated[0], ["port_breakwater_n", "port_breakwater_s", "port_breakwater_done"], "the path over the gap waits for the breakwater"))

func test_the_build_sites():
	_on(func():
		var post: float = BuildGrid.def("bridgePost").h
		var bw := Data.zone("port_breakwater")
		t.eq(float(bw.spanY), Port.BW_H, "decks over the gap are level with the breakwater")
		t.ok(is_equal_approx(Port.GAP_BED + post, Port.BW_H), "a post in the gap reaches the deck")
		for side in ["a", "b"]:
			var ep: Dictionary = bw.endpoints[side]
			for i in range(int(ep.minI), int(ep.maxI) + 1):
				var g := Heightfield.height(i + 0.5, float(ep.minK) + 0.5)
				t.ok(is_equal_approx(g, Port.BW_H), "end %s of the gap is on the breakwater (cell %d: %.2f)" % [side, i, g])
		var gap_cells := 0
		for i in range(int(bw.minI), int(bw.maxI) + 1):
			for k in range(int(bw.minK), int(bw.maxK) + 1):
				if Port.in_gap(i + 0.5, k + 0.5): gap_cells += 1
		t.ok(gap_cells >= 14, "the site takes in the gap (%d cells)" % gap_cells)
		for id in ["port_fishmarket", "port_bastion", "port_rock", "port_bakery_door", "port_bank_arcade"]:
			var z := Data.zone(id)
			t.ok(not z.is_empty(), "%s is a build site" % id)
			for i in range(int(z.minI), int(z.maxI) + 1):
				for k in range(int(z.minK), int(z.maxK) + 1):
					var x := i + 0.5; var zz := k + 0.5
					t.ok(not Heightfield.is_water(x, zz), "%s: cell %d,%d is dry" % [id, i, k])
					t.ok(not WorldStatics._near_building(x, zz, 0.0), "%s: cell %d,%d is outside the buildings" % [id, i, k])
		var terrace := Data.zone("port_terrace")
		t.eq(terrace.get("unlock", {}).get("flag", ""), "port_home", "the roof terrace is yours once the flat is")
		for i in range(int(terrace.minI), int(terrace.maxI) + 1):
			for k in range(int(terrace.minK), int(terrace.maxK) + 1):
				t.eq(BuildGrid.ground_at(i, k), float(terrace.floorY), "the terrace's cell %d,%d is up on the roof" % [i, k]))

func test_the_lift_runs_once_its_flag_is_set():
	var L := _layout()
	t.ok(not L.features.any(func(f): return f.kind == "stop"), "no lift stops before the power is back")
	Port.adjust(L, {"port_lift_on": true})
	Port.adjust(L, {"port_lift_on": true})
	var stops: Array = L.features.filter(func(f): return f.kind == "stop")
	t.eq(stops.size(), 3, "three stops once it runs, added once")
	t.ok(stops.all(func(f): return f.line == "port_lift"), "all on the lift's line")
	var others := Travel.stops_on(stops[0], L.features)
	t.eq(others.size(), 2, "from one stop you ride to the other two")
	_on(func():
		var levels: Array = stops.map(func(f): return Port.level(f.x, f.z))
		t.ok(levels.has("quay") and levels.has("middle") and levels.has("top"), "a stop on each level (%s)" % str(levels)))

func test_buildings_reach_down_the_slope():
	_on(func():
		var b: Dictionary = Data.layout.buildings.filter(func(x): return x.id == "port_bakery")[0]
		var o := Port.building(b)
		var base := Heightfield.height(b.x, b.z)
		var low := INF
		for c in o.get_children():
			if c is MeshInstance3D: low = minf(low, c.position.y + c.get_aabb().position.y)
		t.ok(base > Port.QUAY_H + 2.0, "the bakery stands on the slope (%.1f m)" % base)
		t.ok(base + low <= Port.QUAY_H + 0.05, "its front reaches down to the quay (%.2f m)" % (base + low))
		o.free())

func test_you_arrive_off_the_train_as_if_you_had_played_the_way_here():
	var s := Progress.as_if_played(EARLIER, "port")
	t.eq(s.island, "port", "the save is in Tonnarella")
	t.ok(s.flags.get("metropolis_angel_lit", false), "Toriano's finale is behind you")
	var L := _layout()
	t.eq(Vector2(s.player.x, s.player.z), Vector2(L.arrive.x, L.arrive.z), "you stand where the train leaves you")
	_on(func(): t.eq(Port.level(L.arrive.x, L.arrive.z), "top", "on the station forecourt, at the top"))
