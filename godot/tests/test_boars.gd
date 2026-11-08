extends RefCounted
var t

func test_the_bakery_boars_stand_where_you_can_reach_them():
	Data.use_island("hearthglow")
	for spot in WorldActions.SQUIRREL_SPOTS:
		var p := Vector2(float(spot[0]), float(spot[1]))
		for b in Data.layout.buildings:
			var cx := clampf(p.x, b.x - b.w / 2.0, b.x + b.w / 2.0)
			var cz := clampf(p.y, b.z - b.d / 2.0, b.z + b.d / 2.0)
			t.ok(p.distance_to(Vector2(cx, cz)) >= 1.0 or b.id == "bakery", "the boar at %s has room to wander and be reached, clear of %s" % [p, b.id])

func test_a_fed_boar_goes_back_into_the_woods():
	Data.use_island("hearthglow")
	var bakery := Vector2(float(WorldActions.SQUIRREL_SPOTS[0][0]), float(WorldActions.SQUIRREL_SPOTS[0][1]))
	var woods: Array = Data.layout.get("decor", {}).get("woods", [])
	for n in WorldActions.SQUIRREL_SPOTS.size():
		var home := WorldActions.woods_home(n)
		t.ok(woods.any(func(w): return home.distance_to(Vector2(float(w.x), float(w.z))) < float(w.r)), "boar %d settles inside a wood (%s)" % [n, home])
		t.ok(home.distance_to(bakery) > 15.0, "boar %d is well away from the bakery (%.1f m)" % [n, home.distance_to(bakery)])

func _feed_step() -> Dictionary:
	return Data.quest("squirrels").objectives.filter(func(o): return o.id == "feed")[0]

func _boar_request() -> Dictionary:
	var s := GameState.new_game()
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}}
	s.quests["squirrels"] = {"status": "active", "progress": {}}
	return s

func test_every_boar_fed_counts_even_before_its_step():
	Data.use_island("hearthglow")
	var s := _boar_request()
	var e := QuestEngine.new(s)
	s.inventory["acorn"] = 1
	s.flags["squirrelFed1"] = true
	WorldActions.count_boars(s)
	e.on_event("feed")
	t.eq(e.current_stage("squirrels"), 0, "a boar fed while you're still gathering chestnuts")
	s.inventory["acorn"] = 3
	e.refresh()
	t.eq(e.current_stage("squirrels"), 1, "three chestnuts in the bag: on to the boars")
	for n in [0, 2]:
		s.flags["squirrelFed%d" % n] = true
		WorldActions.count_boars(s)
		e.on_event("feed")
	t.ok(e.objective("squirrels", _feed_step()).done, "the two left at the bakery finish it: the early one counted too")

func test_a_save_with_a_boar_lost_to_the_woods_can_finish():
	Data.use_island("hearthglow")
	var s := _boar_request()
	s.quests.squirrels.progress = {"acorns": 3, "feed": 2}
	for n in 3: s.flags["squirrelFed%d" % n] = true
	var e := QuestEngine.new(s)
	t.ok(not e.objective("squirrels", _feed_step()).done, "an old save: all three fed, only two counted")
	t.ok(WorldActions.count_boars(s), "loading counts the boars that are fed")
	e.invalidate()
	t.ok(e.objective("squirrels", _feed_step()).done, "and the step is done, with no boar left to find")
	t.ok(not WorldActions.count_boars(s), "counting again changes nothing")
	s.flags["squirrelsGone"] = true
	WorldActions.count_boars(s)
	t.eq(int(s.stats.bakeryBoars), WorldActions.SQUIRREL_SPOTS.size(), "once the request is done every boar counts as fed")
