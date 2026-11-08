extends RefCounted
var t

func _unique(a: Array) -> bool:
	var seen: Array = []
	for x in a:
		if seen.has(x): return false
		seen.append(x)
	return true

func test_arriving_in_casalrana_announces_no_approval_milestones():
	var s := Progress.as_if_played(["hearthglow", "river_town"], "rice_village")
	var reached: Array = Data.harmony_unlocks.filter(func(u): return int(u.at) <= int(s.harmony))
	t.ok(reached.size() >= 5, "Monteforchetta and Boccapioppo take approval past the milestones (%d at %d approval)" % [reached.size(), int(s.harmony)])
	t.ok(reached.all(func(u): return s.unlocks_seen.has(u.id)), "every milestone reached on the way is already seen: %s" % str(s.unlocks_seen))
	t.ok(_unique(s.unlocks_seen), "and noted once each: %s" % str(s.unlocks_seen))
	t.eq(int(s.approval_best), int(s.harmony), "the best approval so far is the approval those places gave")
	t.eq(Harmony.due(s, "rice_village"), [], "nothing is due on arrival")
	t.eq(Needs.raise(s, 1), [], "a first bed's +1 passes no milestone")
	t.eq(Harmony.due(s, "rice_village"), [], "and still nothing is due in Casalrana")
	t.eq(Harmony.due(s, "hearthglow"), [], "nor back in Monteforchetta")
	var gauge: Array = LocationMeter.def("river_town").get("milestones", []).filter(func(u): return int(u.at) <= LocationMeter.points(s, "river_town"))
	t.ok(not gauge.is_empty() and gauge.all(func(u): return LocationMeter.reached(s, u)), "Boccapioppo's gauge milestones on the way are seen too")
	t.ok(_unique(s.unlocks_seen), "still without duplicates")

func test_approval_milestones_wait_for_a_place_that_shows_approval():
	var s := GameState.new_game("Tester")
	t.ok(not Harmony.shown_on("rice_village") and not Harmony.shown_on("river_town") and not Harmony.shown_on("metropolis"), "places with their own meter don't show approval")
	t.ok(Harmony.shown_on("hearthglow") and Harmony.shown_on("clockwork"), "Monteforchetta and Clockwork Cove do")
	Needs.raise(s, 20)
	t.eq(Harmony.due(s, "rice_village"), [], "approval reaching 20 in Casalrana announces nothing there")
	t.eq(Harmony.due(s, "hearthglow").map(func(u): return u.id), ["cozy"], "back in Monteforchetta, the 15 milestone is waiting")
	Needs.raise(s, 40)
	t.eq(Harmony.due(s, "hearthglow").map(func(u): return u.id), ["cozy", "plot"], "and the 50 one joins it, in order")
	t.ok(GameState.see_unlock(s, "cozy"), "seeing a milestone notes it")
	t.ok(not GameState.see_unlock(s, "cozy"), "seeing it again doesn't")
	t.eq(s.unlocks_seen, ["cozy"], "so it's there once")
	t.eq(Harmony.due(s, "hearthglow").map(func(u): return u.id), ["plot"], "and isn't due any more")
	Needs.settle(s, -60)
	Needs.settle(s, 0)
	t.eq(Harmony.due(s, "hearthglow").map(func(u): return u.id), ["plot"], "approval dipping and coming back doesn't bring it back")
	t.ok(not GameState.see_unlock(s, ""), "a milestone without an id isn't noted")

func test_a_save_never_loads_a_milestone_twice():
	var s := GameState.new_game("Tester")
	s.unlocks_seen = ["cozy", "plot", "lights", "cozy", "plot", "lights", "rice_village_page", "rice_village_page"]
	var back := SaveSystem.deserialize(SaveSystem.serialize(s))
	t.eq(back.unlocks_seen, ["cozy", "plot", "lights", "rice_village_page"], "duplicates from an older save are dropped, in order")
