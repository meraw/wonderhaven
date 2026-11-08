extends RefCounted
var t

func test_arriving_somewhere_as_if_monteforchetta_was_played():
	var s := Progress.as_if_played(["hearthglow"], "river_town")
	var main: Array = Data.quests.filter(func(q): return q.get("main", false) and Data.quest_island(q.id) == "hearthglow")
	t.ok(main.size() >= 5 and main.all(func(q): return s.quests.get(q.id, {}).get("status", "") == "done"), "every Monteforchetta story request is done (%d)" % main.size())
	t.ok(not s.quests.has("catch") and not s.quests.has("stones"), "side requests are left for later: the least any player arriving has")
	var approval := 0; var lire := 0
	for q in main:
		approval += int(q.get("rewards", {}).get("harmony", 0)); lire += int(q.get("rewards", {}).get("items", {}).get("coins", 0))
	t.eq(int(s.harmony), approval, "approval is what those requests gave")
	t.eq(int(s.approval_best), int(s.harmony), "and it's the best approval so far, so the next point of approval doesn't announce every milestone on the way up again")
	var reached: Array = Harmony.between(int(s.approval_best), int(s.harmony) + 1)
	t.ok(reached.all(func(u): return float(u.at) > float(s.harmony)), "one more point of approval reaches no milestone already passed (%s)" % str(reached.map(func(u): return u.at)))
	t.eq(int(s.inventory.get("coins", 0)), lire, "and so are the lire")
	t.ok(s.flags.get("hasTool", false) and s.flags.get("orchardOpen", false) and s.flags.get("boatReady", false) and s.flags.get("homePlot", false), "their flags are set: the kit, the crossing, the bus line, the farmhouse deed")
	t.ok(s.blueprints.has("flowerBed") and s.blueprints.has("roof") and s.blueprints.has("gardenPath"), "with the plans they gave, the deed's and accepting's included")
	for u in Data.harmony_unlocks:
		if float(u.at) <= float(s.harmony):
			t.ok(u.get("blueprints", []).all(func(b): return s.blueprints.has(b)) and u.get("clothes", []).all(func(c): return s.clothes_owned.has(c)), "and the approval milestone at %d" % int(u.at))
	t.ok(int(s.relationships.get("captain", {}).get("hearts", 0)) > 0, "the villagers you helped are friendlier")
	t.ok(not s.tutorial.on, "the guided first day is behind you")
	var L: Dictionary = Data.read_layout("river_town")
	var at: Dictionary = L.get("arrive", L.spawn)
	t.ok(s.island == "river_town" and is_equal_approx(s.player.x, float(at.x)) and is_equal_approx(s.player.z, float(at.z)), "standing where travellers arrive there")
	t.ok(s.placements.is_empty(), "nothing built yet in the new place")

func test_nothing_played_is_a_new_game_without_the_guide():
	var s := Progress.as_if_played([], "hearthglow")
	t.ok(s.quests.is_empty() and int(s.harmony) == 0 and not s.tutorial.on, "no requests done, no approval, no guided day")

func test_the_city_bus_reaches_boccapioppo_first():
	# Monteforchetta's finale opens the bus line to Boccapioppo; Casalrana comes after Boccapioppo, Toriano after Casalrana
	var before := Progress.as_if_played([], "hearthglow")
	var after := Progress.as_if_played(["hearthglow"], "hearthglow")
	var shown := func(id: String, s: Dictionary) -> bool: return Travel.on_map(Data.island_def(id), s.flags, "hearthglow")
	t.ok(not shown.call("river_town", before), "before the city bus, Boccapioppo isn't on the map")
	t.ok(shown.call("river_town", after), "after it, Boccapioppo is")
	t.ok(not shown.call("rice_village", after) and not shown.call("metropolis", after), "Casalrana and Toriano wait for later")
