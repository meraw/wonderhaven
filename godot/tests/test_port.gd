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
		for id in ["port_breakwater_s", "port_rock", "port_keeper_door", "port_tower_door"]:
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
		for id in ["port_fishmarket", "port_bastion", "port_rock", "port_bakery_door", "port_bank_arcade", "port_arcade"]:
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
	t.ok(not L.features.any(func(f): return f.kind == "stop" and f.get("line", "") == "port_lift"), "no lift stops before the power is back")
	Port.adjust(L, {"port_lift_on": true})
	Port.adjust(L, {"port_lift_on": true})
	var stops: Array = L.features.filter(func(f): return f.kind == "stop" and f.get("line", "") == "port_lift")
	t.eq(stops.size(), 3, "three stops once it runs, added once")
	t.ok(stops.all(func(f): return f.line == "port_lift"), "all on the lift's line")
	var others := Travel.stops_on(stops[0], L.features)
	t.eq(others.size(), 2, "from one stop you ride to the other two")
	_on(func():
		var levels: Array = stops.map(func(f): return Port.level(f.x, f.z))
		t.ok(levels.has("quay") and levels.has("middle") and levels.has("top"), "a stop on each level (%s)" % str(levels)))

func _low_top(o: Node3D) -> Vector2:
	var low := INF
	var top := -INF
	for c in o.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != o:
			if p is Node3D: xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var bb := xf * mi.get_aabb()
		low = minf(low, bb.position.y)
		top = maxf(top, bb.end.y)
	return Vector2(low, top)

func test_every_building_reaches_down_its_slope_and_above_it():
	_on(func():
		for b in Data.layout.buildings:
			if b.kind in ["port_solid", "port_lantern"] or b.get("onRoof", false): continue
			var o: Node3D = Port.building(b)
			t.ok(o != null and o.get_child_count() > 0, "%s has a model" % b.id)
			var base := Port.base_of(b)
			var lo := INF
			var hi := -INF
			for fx in [-0.45, 0.0, 0.45]:
				for fz in [-0.45, 0.0, 0.45]:
					var g := maxf(Port.SEA, Heightfield.height(float(b.x) + fx * float(b.w), float(b.z) + fz * float(b.d)))
					lo = minf(lo, g); hi = maxf(hi, g)
			var lt := _low_top(o)
			t.ok(base + lt.x <= lo + 0.06, "%s reaches down to the lowest ground under it (%.2f, ground %.2f)" % [b.id, base + lt.x, lo])
			t.ok(base + lt.y >= hi + 1.5, "%s stands above the highest ground under it (%.2f, ground %.2f)" % [b.id, base + lt.y, hi])
			o.free())

func test_rooms_you_can_walk_into():
	_on(func():
		var rooms: Array = Data.layout.buildings.filter(func(b): return Interiors.enterable(b))
		var ids: Array = rooms.map(func(b): return b.id)
		for want in ["port_bakery", "port_bank", "port_harbour_office", "port_keeper", "port_flat", "port_lantern"]:
			t.ok(ids.has(want), "%s is a room you can walk into" % want)
		for b in rooms:
			var base := Port.base_of(b)
			var room := Interiors.room(b, base)
			for fx in [-0.4, 0.0, 0.4]:
				for fz in [-0.4, 0.0, 0.4]:
					var x: float = float(b.x) + fx * room.size.x
					var z: float = float(b.z) + fz * room.size.z
					var floor_y := maxf(Heightfield.height(x, z), WorldStatics.floor_top(x, z))
					t.ok(absf(floor_y - base) < 0.06, "%s: a level floor at %.2f (%.2f at %.1f, %.1f)" % [b.id, base, floor_y, x, z])
			t.ok(Data.layout.nav_nodes.has(String(b.navDoor)), "%s: its door opens onto %s" % [b.id, b.navDoor])
			var door: Array = Data.layout.nav_nodes[b.navDoor]
			t.ok(not room.has_point(Vector3(door[0], base, door[1])), "%s: the spot outside its door is outside" % b.id)
			t.ok(Data.layout.nav_nodes.has(String(b.id) + ":spot"), "%s: someone can stand inside" % b.id)
			for it in Interiors.items(b):
				t.ok(it.x > room.position.x and it.x < room.end.x and it.z > room.position.z and it.z < room.end.z, "%s: the %s is inside" % [b.id, it.id]))

func test_the_flat_is_up_the_112_steps():
	_on(func():
		var stops: Array = Data.layout.features.filter(func(f): return f.kind == "stop" and f.get("line", "") == "port_stairs")
		t.eq(stops.size(), 2, "the stairs have two ends")
		var street: Dictionary = stops.filter(func(f): return not f.has("y"))[0]
		var roof: Dictionary = stops.filter(func(f): return f.has("y"))[0]
		t.eq(Heightfield.height(street.x, street.z), Port.MID_H, "the street door is in the alleys")
		t.ok(String(street.arrive_text).contains("112"), "the climb is counted to 112")
		t.eq(Travel.stops_on(street, Data.layout.features).map(func(f): return f.id), [roof.id], "from the street door the stairs go up to the flat")
		var flat: Dictionary = Data.layout.buildings.filter(func(b): return b.id == "port_flat")[0]
		t.eq(float(roof.y), float(flat.y), "the top of the stairs is on the flat's floor")
		t.eq(WorldStatics.floor_top(36.0, -5.0), float(flat.y), "the roof terrace is the palazzo's roof")
		var w := _walker()
		var off := _walk(w, Vector2(38.0, -5.0), Vector2(46.0, -5.0))
		t.ok(not off.ok and absf(off.y - float(flat.y)) < 0.05, "a railing keeps you on the roof (%s)" % str(off.at))
		var front := _walk(w, Vector2(36.0, -5.0), Vector2(36.0, 2.0))
		t.ok(not front.ok and absf(front.y - float(flat.y)) < 0.05, "and on the street side")
		var wardrobe: Dictionary = Data.layout.features.filter(func(f): return f.kind == "wardrobe")[0]
		t.eq(wardrobe.get("flag", ""), "port_home", "the wardrobe is yours once the flat is")
		t.ok(absf(float(wardrobe.x) - float(flat.x)) < float(flat.w) / 2.0 and absf(float(wardrobe.z) - float(flat.z)) < float(flat.d) / 2.0, "and it stands in the flat"))

func test_the_lantern_is_up_the_tower():
	_on(func():
		var stops: Array = Data.layout.features.filter(func(f): return f.kind == "stop" and f.get("line", "") == "port_lantern")
		t.eq(stops.size(), 2, "the lighthouse stair has two ends")
		var lantern: Dictionary = Data.layout.buildings.filter(func(b): return b.id == "port_lantern")[0]
		var tower: Dictionary = Data.layout.buildings.filter(func(b): return b.id == "port_lighthouse")[0]
		t.ok(absf(float(lantern.y) - (float(tower.y) + float(tower.h))) < 0.01, "the lantern room stands on top of the tower")
		t.ok(stops.any(func(f): return f.has("y") and absf(float(f.y) - float(lantern.y)) < 0.01), "the stair comes out on the gallery")
		var w := _walker()
		var off := _walk(w, Vector2(42.0, 82.5), Vector2(42.0, 76.0))
		t.ok(not off.ok and absf(off.y - float(lantern.y)) < 0.05, "a railing round the gallery (%s)" % str(off.at)))

func test_trees_pillars_and_scenery_stand_clear():
	_on(func():
		for pr in Data.layout.props:
			if not String(pr.kind).begins_with("port_") or not pr.get("solid", true): continue
			if pr.has("y") and String(pr.kind) != "port_pillar": continue
			t.ok(not Heightfield.is_water(pr.x, pr.z), "%s stands on dry land" % pr.id)
			t.ok(not WorldStatics._near_building(pr.x, pr.z, 0.0), "%s isn't inside a building" % pr.id)
			t.ok(not WorldStatics._in_zone(pr.x, pr.z, 0.0), "%s isn't on a build site" % pr.id)
		var pillars: Array = Data.layout.props.filter(func(pr): return pr.kind == "port_pillar")
		t.ok(pillars.size() >= 12, "pillars hold up the arcades (%d)" % pillars.size())
		for pr in pillars:
			var under: bool = Data.layout.buildings.any(func(b): return float(b.get("portico", 0.0)) > 0.0 and absf(pr.x - float(b.x)) < float(b.w) / 2.0)
			t.ok(under and Port.level(pr.x, pr.z) == "quay", "%s stands on the quay under an arcade" % pr.id))

func test_the_scenery_and_the_horizon_are_built():
	_on(func():
		var root := Node3D.new()
		Port.dress(root)
		var scenery := root.find_child("port_scenery", false, false)
		var horizon := root.find_child("port_horizon", false, false)
		t.ok(scenery != null and scenery.get_child_count() > 60, "the scenery is built")
		t.ok(horizon != null, "the horizon is built")
		t.ok(root.find_children("port_tunnel*", "", true, false).size() == 2, "the railway runs into a tunnel at each end")
		t.ok(root.find_child("port_nonna_balcony", true, false) != null, "Nonna Pina's balcony is full of basil")
		t.ok(root.find_children("port_crane*", "", true, false).size() >= 4, "cranes stand in the port across the bay")
		t.ok(root.find_children("port_fort*", "", true, false).size() >= 3, "forts stand on the ridges")
		t.ok(root.find_child("port_ferry", true, false) != null, "a ferry lies in the port")
		var far: MeshInstance3D = root.find_child("port_far_land", true, false)
		t.ok(far != null and far.mesh.get_aabb().end.y > 150.0, "the mountains rise behind the city")
		root.free())

func test_you_arrive_off_the_train_as_if_you_had_played_the_way_here():
	var s := Progress.as_if_played(EARLIER, "port")
	t.eq(s.island, "port", "the save is in Tonnarella")
	t.ok(s.flags.get("metropolis_angel_lit", false), "Toriano's finale is behind you")
	var L := _layout()
	t.eq(Vector2(s.player.x, s.player.z), Vector2(L.arrive.x, L.arrive.z), "you stand where the train leaves you")
	_on(func(): t.eq(Port.level(L.arrive.x, L.arrive.z), "top", "on the station forecourt, at the top"))

func test_prices_show_both_currencies_from_arrival():
	var c: Dictionary = Data.island_def("port").get("currency", {})
	for k in ["both", "first", "euro"]: t.ok(String(c.get(k, "")).begins_with("port_euro_"), "the changeover's %s flag is Tonnarella's" % k)
	t.eq(Money.mode_for({}, "port"), "both", "prices in Tonnarella show both from arrival")
	t.eq(Money.mode_for({}, "river_town"), "lire", "the other places keep lire until the changeover")
	t.eq(Money.mode_for({c.both: true}, "river_town"), "both", "then both everywhere")
	t.eq(Money.mode_for({c.both: true, c.first: true, c.euro: true}, "hearthglow"), "euro", "and in the end euros only, everywhere")

const PEOPLE := ["port_nicolo", "port_gerolamo", "port_lorenzo", "port_rosetta", "port_giobatta", "port_pina", "port_agostino", "port_stefano", "port_davide"]
const MAIN := ["port_welcome", "port_breakwater", "port_fishmarket", "port_lift", "port_lighthouse"]
const SIDE := ["port_queue", "port_seagulls", "port_labels", "port_lampara", "port_nonna_lire"]
const WASHING := ["tablecloth", "shirt", "longjohns", "apron", "gloves"]

func _port_quests() -> Array: return Data.quests.filter(func(q): return Data.quest_island(q.id) == "port")

func test_nine_villagers_live_in_tonnarella():
	var here: Array = Data.npcs.filter(func(n): return Data.npc_island(n.id) == "port").map(func(n): return String(n.id))
	here.sort()
	var want := PEOPLE.duplicate()
	want.sort()
	t.eq(here, want, "the nine villagers of the cast")
	for id in PEOPLE:
		var n := Data.npc(id)
		var a := Chibi.sanitize(n.appearance)
		for k in ["skin", "hairColor", "topColor", "bottomColor", "shoesColor", "hatColor"]:
			t.eq(a[k], n.appearance[k], "%s keeps their own %s" % [id, k])
		for k in ["top", "bottom", "hat", "accessory"]:
			t.eq(a[k], n.appearance[k], "%s wears their own %s" % [id, k])
		t.ok(Data.quests.any(func(q): return q.giver == id), "%s gives a request" % id)
		t.ok(not Tastes.of(id).is_empty(), "%s has tastes" % id)

func test_villagers_are_where_the_story_needs_them():
	_on(func():
		var at := func(id: String, minute: float, flags: Dictionary) -> String: return String(Schedule.activity_at(Data.npc(id), minute, flags).node)
		t.eq(at.call("port_nicolo", 600.0, {}), "port_forecourt", "Nicolò meets the train on the forecourt")
		t.eq(at.call("port_nicolo", 600.0, {"port_nicolo_met": true}), "port_bank:spot", "then goes down to the bank")
		t.eq(at.call("port_nicolo", 600.0, {"port_nicolo_met": true, "port_lorenzo_met": true}), "port_home_door", "and waits at your street door while you climb")
		t.eq(at.call("port_nicolo", 600.0, {"port_nicolo_met": true, "port_lorenzo_met": true, "port_welcomed": true}), "port_bank:spot", "then works at the bank")
		t.eq(at.call("port_gerolamo", 360.0, {}), "port_keeper:spot", "Gerolamo is stranded at the lighthouse")
		t.eq(at.call("port_gerolamo", 360.0, {"port_breakwater_open": true}), "port_bakery_door", "until he can walk to the bakery at dawn")
		t.eq(at.call("port_gerolamo", 22.0 * 60.0, {"port_glazing": true}), "port_tower_door", "and waits at the lighthouse door after dark for the finale")
		var doing := func(id: String, minute: float, flags: Dictionary) -> String: return String(Schedule.activity_at(Data.npc(id), minute, flags).activity)
		t.eq(doing.call("port_rosetta", 60.0, {"port_finale_night": true}), "work", "Rosetta stays open all night after the lighting")
		t.eq(doing.call("port_rosetta", 60.0, {"port_finale_night": true, "port_lighthouse_lit": true}), "sleep", "and then goes back to her hours")
		t.eq(at.call("port_stefano", 21.0 * 60.0, {}), "port_stefano_boat", "Stefano is at his boat at night")
		t.eq(at.call("port_giobatta", 6.0 * 60.0, {}), "port_fishmarket", "Baciccia sells at dawn")
		t.eq(at.call("port_pina", 11.0 * 60.0, {"port_lift_on": true}), "port_bank_door", "Nonna comes down to the harbour once the lift runs")
		var crowd := 0
		for id in PEOPLE:
			if String(at.call(id, 21.0 * 60.0, {"port_lighthouse_ready": true, "port_glazing": true})).begins_with("port_bw_"): crowd += 1
		t.ok(crowd >= 5, "on the night of the lighting the town gathers on the breakwater (%d)" % crowd)
		var flags := {}
		for q in Data.quests:
			for f in q.get("rewards", {}).get("flags", []): flags[f] = true
		for id in PEOPLE:
			var n := Data.npc(id)
			var spots := [String(n.home)]
			for e in n.schedule: spots.append(String(e[2]))
			for w in n.get("when", []):
				for e in w.schedule: spots.append(String(e[2]))
			for spot in spots:
				t.ok(Data.layout.nav_nodes.has(spot), "%s goes to a real spot (%s)" % [id, spot])
				t.ok(not spot.begins_with("port_lantern"), "%s never has to climb the lighthouse (%s)" % [id, spot])
				var path := Schedule.find_path(Schedule.nearest_node(-8.0, -58.0, flags), spot, flags)
				t.ok(not path.is_empty(), "%s can walk to %s" % [id, spot]))

func test_ten_requests_and_the_washing():
	var ids: Array = _port_quests().map(func(q): return String(q.id))
	for id in MAIN + SIDE: t.ok(ids.has(id), "%s is a request" % id)
	for w in WASHING: t.ok(ids.has("port_wash_" + w), "the %s is a lost thing to bring back" % w)
	t.eq(ids.size(), 15, "five main, five side, five pieces of washing")
	for id in MAIN: t.ok(Data.quest(id).get("main", false), "%s is the main story" % id)
	for i in range(1, MAIN.size()): t.eq(Data.quest(MAIN[i]).requires.quests, [MAIN[i - 1]], "%s follows %s" % [MAIN[i], MAIN[i - 1]])
	for q in _port_quests():
		for o in q.objectives:
			if o.kind != "commission": continue
			t.ok(o.musts.size() >= 1 and o.musts.size() <= 3, "%s: one to three musts" % q.id)
			t.ok(o.get("wishes", []).size() <= 3, "%s: at most three wishes" % q.id)
			for c in o.musts + o.get("wishes", []): t.ok(Commission.KINDS.has(String(c.check)), "%s: a real check (%s)" % [q.id, c.check])
			for c in o.get("wishes", []): t.ok(PEOPLE.has(String(c.get("who", ""))), "%s: a wish from someone in town (%s)" % [q.id, c.get("who", "")])
			t.ok(o.has("plan") and not o.plan.is_empty(), "%s: the brief has a ghost plan" % q.id)

func test_the_changeover_adds_up_to_one_hundred():
	var total := 0
	var without := 0
	for q in _port_quests():
		var m := int(q.get("rewards", {}).get("meter", 0))
		total += m
		if q.id != "port_lighthouse": without += m
		if MAIN.has(q.id): t.eq(m, 15, "%s moves the changeover 15" % q.id)
		elif SIDE.has(q.id): t.eq(m, 4, "%s moves it 4" % q.id)
		else: t.eq(m, 1, "%s moves it 1" % q.id)
	t.eq(total, 100, "everything together makes 100%")
	t.eq(without, 85, "without the finale it stops at 85%")
	var m := LocationMeter.def("port")
	t.eq(LocationMeter.reading(m, 0), "0%", "the meter reads 0% on arrival")
	t.eq(LocationMeter.reading(m, 15), "15%", "and 15% after the first request")
	var s := {"meters": {}, "quests": {}, "flags": {}, "unlocks_seen": []}
	t.eq(LocationMeter.add(s, "port", 15).map(func(u): return String(u.id)), ["port_euro_both"], "the first request passes 10%: prices in both")
	var last: Dictionary = m.milestones.back()
	t.eq(int(last.at), 100, "the last lira at 100%")
	t.ok(not LocationMeter.requirements_met(s, last), "and it waits for the finale")
	s.quests["port_lighthouse"] = {"status": "done"}
	t.ok(LocationMeter.requirements_met(s, last), "which lets it through")

func test_the_milestones_switch_the_whole_game_to_euros():
	var flags := {}
	for u in LocationMeter.def("port").milestones:
		for f in u.get("flags", []): flags[f] = true
		var mode := Money.mode_for(flags, "hearthglow")
		if int(u.at) == 10: t.eq(mode, "both", "10%: prices in both, everywhere")
		if int(u.at) == 50: t.eq(mode, "first", "50%: euros first")
		if int(u.at) == 100: t.eq(mode, "euro", "100%: euros only")
	var owned: Array = []
	for u in LocationMeter.def("port").milestones: owned.append_array(u.get("clothes", []))
	t.eq(owned, ["port_woolcap", "port_sweater"], "the wool cap and the fisherman's sweater")
	for c in owned: t.ok(Data.appearance.variants.has(c), "%s is in the wardrobe" % c)

func test_every_brief_is_built_by_its_plan():
	_on(func():
		var here := WorldStatics.build_statics(WorldStatics.generate_decor())
		for q in _port_quests():
			var placements: Array = []
			for o in q.objectives:
				if not o.has("plan"): continue
				var zone := Data.zone(String(o.zone))
				var ok := true
				for pl in Plans.lay_out(o.plan, zone, placements):
					var y := BuildGrid.suggest_bottom(pl.id, pl.i, pl.k, int(pl.r), 10.0, placements, zone)
					if absf(y - float(pl.y)) > 0.01:
						t.ok(false, "%s: the ghost %s at (%d, %d) sits at %.2f, but builds at %.2f" % [q.id, pl.id, pl.i, pl.k, pl.y, y]); ok = false; break
					pl.uid = placements.size() + 1
					var v := BuildGrid.validate_placement(pl, {"placements": placements, "zones": Data.layout.zones, "statics": here, "bodies": [], "flags": {}})
					if not v.ok:
						t.ok(false, "%s: %s at (%d, %d) turned %d can't be built: %s" % [q.id, pl.id, pl.i, pl.k, pl.r, v.reason]); ok = false; break
					placements.append(pl)
				if not ok: continue
				var m := Mechanics.solve(placements, Data.layout.get("machines", []))
				var path := func(zone_id: String) -> Dictionary:
					var w := WalkWorld.new(here, func(_f): return false)
					w.floors = WorldStatics.floors()
					w.surfaces = BuildGrid.surfaces_for(placements)
					return Validate.path_across(Data.zone(zone_id), w)
				var r := Commission.evaluate(o, {"placements": placements, "lamps": m.lamps, "fed": m.fed, "mech": m, "path": path})
				t.ok(r.done, "%s: building its plan meets the brief (%s)" % [q.id, str(r.musts.map(func(x): return "%s %s" % [x.label, x.ok]))]))

func test_the_breakwater_once_built_can_be_walked_to_the_lighthouse():
	_on(func():
		var o: Dictionary = Data.quest("port_breakwater").objectives.filter(func(x): return x.kind == "commission")[0]
		var placements: Array = []
		for pl in Plans.lay_out(o.plan, Data.zone("port_breakwater"), placements):
			pl.uid = placements.size() + 1
			placements.append(pl)
		var w := _walker()
		w.surfaces = BuildGrid.surfaces_for(placements)
		var a := _walk(w, _node("port_breakwater_n"), Vector2(39.5, 52.5))
		var b := _walk(w, Vector2(39.5, 52.5), Vector2(39.5, 62.5))
		var c0 := _walk(w, Vector2(39.5, 62.5), _node("port_breakwater_s"))
		t.ok(a.ok and b.ok and c0.ok, "from the quay end along the planks to the lighthouse side (%s, %s, %s)" % [str(a.at), str(b.at), str(c0.at)])
		var off := _walk(w, Vector2(39.5, 56.5), Vector2(36.5, 56.5))
		t.ok(not off.ok, "and the railings keep you on the planks (%s)" % str(off.at))
		var c := _walk(w, _node("port_breakwater_s"), _node("port_rock"))
		t.ok(c.ok, "and on to the lighthouse rock"))

func test_night_fishing_under_the_lampara():
	_on(func():
		var fish: Array = Data.layout.get("fish", [])
		var night := Minigames.catch_table(fish, "port_lampara_spot", {"port_lampara_on": true}, 21.0 * 60.0)
		t.eq(night.map(func(f): return String(f.id)), ["port_anchovy"], "under the lamp after dark: anchovies")
		var quay := Minigames.catch_table(fish, "port_fish0", {}, 21.0 * 60.0)
		t.ok(not quay.any(func(f): return f.id == "port_anchovy"), "never off the quays")
		t.ok(quay.any(func(f): return f.id == "port_lire_purse"), "where a purse of old lire can come up")
		var spot := Data.node_def("port_lampara_spot")
		t.eq(spot.get("flag", ""), "port_lampara_on", "the spot is Stefano's once he asks")
		t.ok(Data.quest("port_lampara").onAccept.flags.has("port_lampara_on"), "and he asks in his request")
		for n in Data.layout.nodes.filter(func(x): return x.kind == "fish"):
			var f := float(n.get("facing", PI))
			var bob := Vector2(float(n.x) + sin(f) * 3.0, float(n.z) + cos(f) * 3.0)
			t.ok(not Heightfield.is_water(n.x, n.z), "%s: you stand on dry ground to fish" % n.id)
			t.ok(Heightfield.is_water(bob.x, bob.y), "%s: the float lands in the sea" % n.id))

func test_nonnas_tins_need_the_detector():
	_on(func():
		var tins: Array = Data.layout.nodes.filter(func(n): return n.kind == "dig")
		t.eq(tins.size(), 5, "five tins hidden round town")
		for n in tins:
			t.eq(n.get("flag", ""), "port_nonna_asked", "%s turns up once Nonna asks" % n.id)
			t.eq(int(n.get("gives", {}).get("port_lire_tin", 0)), 1, "%s is one of her tins" % n.id)
		var acc: Array = Data.quest("port_nonna_lire").onAccept.flags
		t.ok(acc.has(WorldActions.DETECTOR) and acc.has("port_nonna_asked"), "she lends you the metal detector"))

func test_the_washing_goes_back_on_the_line():
	_on(func():
		for w in WASHING:
			var n := Data.node_def("port_wash_" + w)
			var q := Data.quest("port_wash_" + w)
			t.ok(n.get("once", false) and n.kind == "fragment", "the %s lies somewhere once" % w)
			t.eq(int(n.get("gives", {}).get("port_wash_" + w, 0)), 1, "and is the %s" % w)
			t.ok(q.onAccept.flags.has(String(n.flag)), "it turns up once its owner asks")
			t.eq(int(q.objectives[1].items.get("port_wash_" + w, 0)), 1, "and goes back to them")
			t.ok(Data.resources.has("port_wash_" + w), "the %s is in the bag" % w))

func test_every_gathering_spot_can_be_reached_on_foot():
	_on(func():
		var w := _walker()
		var flags := {"port_breakwater_done": true, "port_breakwater_open": true}
		for n in Data.layout.nodes:
			if n.kind in ["fish"]: continue
			var at := Vector2(float(n.x), float(n.z))
			var start := Schedule.nearest_node(at.x, at.y, flags)
			var from := _node(start)
			var r := _walk(w, from, at.move_toward(from, 1.6))
			t.ok(r.ok, "%s is a straight walk from the nearest path spot, %s (stopped at %s)" % [n.id, start, str(r.at)]))

func test_the_shops_of_the_harbour():
	for id in ["port_rosetta", "port_giobatta", "port_davide", "port_nicolo"]:
		t.ok(not Shop.def(id).is_empty(), "%s keeps a shop" % id)
	var sells := func(id: String, item: String) -> bool: return Shop.def(id).stock.any(func(l): return l.get("items", {}).has(item))
	t.ok(sells.call("port_davide", "port_glass"), "the chandlery sells glass panes for the lantern")
	t.ok(sells.call("port_davide", "fabric") and sells.call("port_davide", "clay") and sells.call("port_davide", "metal"), "and sailcloth, roof tiles and fittings")
	for item in ["port_focaccia", "port_focaccia_onion", "port_farinata", "port_greens_pie"]:
		t.ok(sells.call("port_rosetta", item), "Rosetta sells %s" % item)
		t.ok(int(Data.resources[item].get("treat", 0)) > 0, "%s is a treat" % item)
	t.ok(Shop.def("port_nicolo").buys.has("port_lire_purse"), "the bank changes a purse of old lire")
	t.ok(not Shop.def("port_nicolo").buys.has("port_lire_tin"), "but Nonna's tins go back to her, not to the till")

func test_tonnarellas_tastes_match_painted_pieces():
	t.ok(not Tastes.of("port_giobatta").is_empty(), "Tonnarella's own tastes file is read")
	var sea_green: String = Data.palette.filter(func(c): return String(c).ends_with("3fb5a3"))[0]
	t.eq(Tastes.likes("port_giobatta", {"id": "counter", "i": 34.0, "k": 26.0, "r": 0, "y": 1.2}), "piece", "Baciccia likes a counter")
	t.eq(Tastes.likes("port_giobatta", {"id": "bench", "i": 34.0, "k": 26.0, "r": 0, "y": 1.2, "color": sea_green}), "colour", "and anything painted sea green from the palette")
	t.eq(Tastes.likes("port_giobatta", {"id": "bench", "i": 34.0, "k": 26.0, "r": 0, "y": 1.2}), "", "but not a plain bench")
