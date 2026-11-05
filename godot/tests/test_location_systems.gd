extends RefCounted
## Small general tools a location's requests can use (they came with Boccapioppo's stage 3, any location can use
## them): a path check and a "sealed" check for any build zone, pieces that float, what a resource node gives, what
## bites at a fishing spot, a request's own weather, and a location's own progress meter.
var t

func _zone(i0: int, i1: int, k0: int, k1: int, extra: Dictionary = {}) -> Dictionary:
	var z := {"id": "zz_test", "name": "Test", "minI": i0, "maxI": i1, "minK": k0, "maxK": k1,
		"endpoints": {"a": {"minI": i0, "maxI": i1, "minK": k0, "maxK": k0}, "b": {"minI": i0, "maxI": i1, "minK": k1, "maxK": k1}}}
	z.merge(extra, true)
	return z

func _place(list: Array, id: String, i: int, k: int, y: float, r: int = 0) -> void:
	list.append({"uid": 500 + list.size(), "id": id, "i": float(i), "k": float(k), "r": r, "y": y})

func test_a_wall_seals_a_zone_only_when_it_is_whole_and_high_enough():
	# a strip of Hearthglow's orchard, 4 cells wide: water would have to cross it from row -40 to row -36
	var ground := -INF
	for i in range(0, 4):
		for k in range(-40, -35): ground = maxf(ground, BuildGrid.ground_at(i, k))
	var zone := _zone(0, 3, -40, -36, {"seal": ground + 1.4})
	var r := Validate.sealed(zone, [])
	t.ok(not r.sealed and r.gap.size() >= 5, "with nothing built, water gets through (a gap of %d cells)" % r.gap.size())
	var wall: Array = []
	for i in range(0, 4):   # a stone block, then sandbags stacked until the wall stands as high as the seal
		var y := BuildGrid.ground_at(i, -38)
		_place(wall, "stoneBlock", i, -38, y); y += 1.0
		while y < float(zone.seal): _place(wall, "sandbags", i, -38, y); y += 0.5
	t.ok(Validate.sealed(zone, wall).sealed, "a whole wall of stone blocks topped with sandbags seals it")
	var low := wall.filter(func(p): return p.id == "stoneBlock")
	t.ok(not Validate.sealed(zone, low).sealed, "a wall that's too low doesn't")
	var holed := wall.filter(func(p): return not (p.i == 2.0))
	var hr := Validate.sealed(zone, holed)
	t.ok(not hr.sealed and hr.gap.any(func(c): return c.x == 2 and c.y == -38), "a wall with a hole lets the water through the hole")
	var floating := wall.duplicate(); floating[0] = {"uid": 900, "id": "stoneBlock", "i": 0.0, "k": -38.0, "r": 0, "y": BuildGrid.ground_at(0, -38) + 0.6}
	t.ok(not Validate.sealed(zone, floating).sealed, "a block that doesn't reach the ground leaves a gap under it")

func test_pontoons_float_and_carry_you_across():
	var zone := Data.zone("bridge")   # Hearthglow's crossing over the stream
	var d := Data.piece("pontoon")
	t.ok(not d.is_empty() and d.get("placeOn", "") == "water" and d.get("walkable", false), "the Pontoon is a walkable piece placed on water")
	var y := BuildGrid.suggest_bottom("pontoon", 0, -19, 0, 5.0, [], zone)
	t.ok(absf(y + float(d.h) - (Heightfield.WATER_Y + BuildGrid.FREEBOARD)) < 0.001, "it floats with its deck just out of the water")
	var ctx := {"placements": [], "zones": [zone], "statics": []}
	var on_water := {"uid": 1, "id": "pontoon", "i": 0.0, "k": -19.0, "r": 0, "y": y}
	t.ok(BuildGrid.validate_placement(on_water, ctx).ok, "it can be moored on the stream")
	var on_land := {"uid": 2, "id": "pontoon", "i": 0.0, "k": -16.0, "r": 0, "y": BuildGrid.float_bottom(d)}
	var v := BuildGrid.validate_placement(on_land, ctx)
	t.ok(not v.ok and String(v.reason).contains("floats"), "not on dry ground: %s" % v.get("reason", ""))
	# a row of pontoons from bank to bank is a path you can walk
	var row: Array = []
	for k in [-21, -19, -17]: row.append({"uid": 10 + row.size(), "id": "pontoon", "i": 0.0, "k": float(k), "r": 0, "y": y})
	var w := WalkWorld.new(WorldStatics.build_statics(WorldStatics.generate_decor()), func(_f): return true)
	w.surfaces = BuildGrid.surfaces_for(row)
	t.ok(Validate.path_across(zone, w).ok, "a row of pontoons across the stream is a walkable crossing")
	var deck := {"uid": 30, "id": "bridgeDeck", "i": 0.0, "k": -18.0, "r": 0, "y": y + float(d.h)}
	t.ok(BuildGrid.compute_support(row + [deck]).supported.has(30), "planks laid on a pontoon are held up by it")

func test_sandbags_stack_into_a_wall():
	var d := Data.piece("sandbags")
	t.ok(not d.is_empty() and d.get("walkable", false) and float(d.h) < 1.0, "Sandbags are a low piece you can stack")
	for k in d.cost: t.ok(Data.resources.has(k), "Sandbags cost %s, a known material" % k)
	t.ok(not Data.starter_blueprints.has("sandbags") and not Data.starter_blueprints.has("pontoon"), "both come as plans from requests, not from the start")

func test_a_node_can_say_what_it_gives():
	t.eq(WorldActions.gives({"kind": "clay"}, {"clay": 2}), {"clay": 2}, "a clay pit gives clay")
	t.eq(WorldActions.gives({"kind": "clay", "gives": {"river_town_sand": 3.0}}, {"clay": 2}), {"river_town_sand": 3}, "or what the layout says: sand from a sandbank")

func test_what_bites_at_a_fishing_spot():
	t.eq(Minigames.catch_table([], "spot", {}, 600.0), Minigames.FISH, "without a list of its own, a place has the shared fish")
	var list := [{"id": "carp", "name": "Carp", "weight": 4.0, "pull": 0.7}, {"id": "boot", "name": "old boot", "weight": 1.0, "pull": 0.2, "item": "zz_boot"},
		{"id": "monster", "name": "monster", "weight": 1000.0, "pull": 2.0, "node": "deep", "flag": "night_fishing", "hours": [20, 4]}]
	var day := Minigames.catch_table(list, "deep", {"night_fishing": true}, 600.0)
	t.ok(day.size() == 2, "the monster doesn't bite by day")
	var night := Minigames.catch_table(list, "deep", {"night_fishing": true}, 22 * 60.0)
	t.ok(night.size() == 3, "it bites at night, at its spot, once the request allows it")
	t.ok(Minigames.catch_table(list, "shallow", {"night_fishing": true}, 22 * 60.0).size() == 2, "...and only at its spot")
	var mg := Minigames.Fish.new(Rng.new(3), [list[2]])
	mg.result = "caught"
	t.eq(mg.fish.id, "monster", "the fish comes from the spot's table")
	var boot := Minigames.Fish.new(Rng.new(3), [list[1]]); boot.result = "caught"
	t.eq(boot.reward(), {"zz_boot": 1}, "a catch can give its own item")
	var fish := Minigames.Fish.new(Rng.new(3), [list[0]]); fish.result = "caught"
	t.eq(fish.reward(), {"fish": 1}, "a fish gives fish")

func test_a_request_can_bring_its_own_weather():
	var s := {"time": {"day": 1, "minute": 1200.0, "total": 5000.0}}
	t.eq(Daylight.forced(s), "", "no weather of its own to begin with")
	Daylight.force(s, "rain", 6)
	t.eq(Daylight.forced(s), "rain", "a storm starts")
	s.time.total = 5000.0 + 5.9 * 60.0
	t.eq(Daylight.forced(s), "rain", "and lasts the hours it was given")
	s.time.total = 5000.0 + 6.1 * 60.0
	t.eq(Daylight.forced(s), "", "then the usual weather comes back")
	s["forced_weather"] = {"type": "hail", "until": 99999.0}
	t.eq(Daylight.forced(s), "", "an unknown kind of weather is ignored")

func test_a_location_can_have_its_own_meter():
	var m := {"name": "Gauge", "icon": "🌊", "reward": "%d cm off", "display": {"from": 7.4, "per_point": -0.01, "format": "%.2f m"},
		"milestones": [{"at": 100, "id": "a", "title": "A", "desc": ""}, {"at": 300, "id": "b", "title": "B", "desc": ""}]}
	t.eq(LocationMeter.reading(m, 0), "7.40 m", "it reads from its starting point")
	t.eq(LocationMeter.reading(m, 160), "5.80 m", "points move the reading (down, for a gauge)")
	var stops := m.duplicate(true); stops.display["to"] = 0.0
	t.eq([LocationMeter.reading(stops, 740), LocationMeter.reading(stops, 900)], ["0.00 m", "0.00 m"], "a display's \"to\" is where the reading stops")
	t.eq(LocationMeter.next_milestone(m, 100).id, "b", "the next milestone")
	t.eq(LocationMeter.between(m, 50, 320).map(func(u): return u.id), ["a", "b"], "milestones passed on the way")
	t.ok(LocationMeter.reward_text(m, 100).contains("100 cm off"), "a reward reads in the meter's own words")
	var s := GameState.new_game()
	t.ok(s.has("meters") and LocationMeter.points(s, "anywhere") == 0, "a new game has no points on any meter")
	LocationMeter.add(s, "anywhere", 40)
	LocationMeter.add(s, "anywhere", 2)
	t.eq(LocationMeter.points(s, "anywhere"), 42, "points add up per location")
	t.eq(LocationMeter.points(SaveSystem.deserialize(SaveSystem.serialize(s)), "anywhere"), 42, "and survive a save")
	t.ok(LocationMeter.def("hearthglow").is_empty(), "Monteforchetta keeps the approval rating")

func test_a_place_can_change_with_the_story():
	t.eq(Data.world_flags_of("hearthglow", {"river_town_launched": true}), {}, "a place without WORLD_FLAGS never changes")
	t.eq(Data.world_flags_of("river_town", {"river_town_launched": true, "hasTool": true}), {"river_town_launched": true}, "only the flags its location script lists reshape it")
	var before = Data.layout
	Data.apply_world_flags({"hasTool": true, "river_town_launched": true})
	t.ok(is_same(Data.layout, before), "flags that don't reshape the place you're on leave its layout alone")

func test_a_particular_lost_thing_is_found_once():
	t.ok(WorldActions.regrows({"kind": "clay"}) and WorldActions.regrows({"kind": "fragment"}), "clay pits and the shared lost things come back")
	t.ok(not WorldActions.regrows({"kind": "fragment", "once": true}) and not WorldActions.regrows({"kind": "chest"}), "a node marked once, like a chest, is gone for good")

func test_villagers_walk_across_what_you_bridged():
	var had := Data.layout.has("crossings")
	var saved = Data.layout.get("crossings")
	Data.layout["crossings"] = [{"a": "zzWest", "b": "zzEast", "zone": "zz_bridge"}]
	var built := {"zz_bridge": [[3, 1], [4, 1], [5, 2]]}
	t.eq(Schedule.crossing("zzWest", "zzEast", built), [Vector2(3.5, 1.5), Vector2(4.5, 1.5), Vector2(5.5, 2.5)], "from the a side to the b side, cell by cell")
	t.eq(Schedule.crossing("zzEast", "zzWest", built)[0], Vector2(5.5, 2.5), "and back the other way")
	t.eq(Schedule.crossing("zzWest", "zzElsewhere", built), [], "not on other paths")
	t.eq(Schedule.crossing("zzWest", "zzEast", {}), [], "nor before anything is built there")
	if had: Data.layout["crossings"] = saved
	else: Data.layout.erase("crossings")
