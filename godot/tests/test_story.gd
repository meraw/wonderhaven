extends RefCounted
var t

func test_quest_data():
	t.ok(Data.quests.filter(func(q): return q.get("main", false)).size() >= 4, "4+ main quests")
	for q in Data.quests:
		t.ok(not Data.npc(q.giver).is_empty(), "%s giver" % q.id)
		t.ok(q.objectives.any(func(o): return o.get("final", false)), "%s ends with a talk" % q.id)
		for k in ["offer", "accept", "progress", "complete"]: t.ok(q.dialogue.has(k), "%s dialogue %s" % [q.id, k])
		for b in q.get("onAccept", {}).get("blueprints", []) + q.get("rewards", {}).get("blueprints", []): t.ok(not Data.piece(b).is_empty(), "%s blueprint %s" % [q.id, b])

func test_npcs():
	t.ok(Data.npcs.size() >= 5)
	for n in Data.npcs:
		var nav: Dictionary = Data.layout.nav_nodes if Data.npc_island(n.id) == Data.island else Data.island_nav(Data.npc_island(n.id))
		t.ok(nav.has(n.home), "%s's home is a nav spot on their island" % n.id)
		t.ok(Data.quests.any(func(q): return q.giver == n.id), "%s gives a quest" % n.id)

func test_quest_flow():
	var s := GameState.new_game()
	var built := [false]
	var e := QuestEngine.new(s, {"bridge": func(): return built[0]})
	t.eq(e.offers_for("fern").size(), 0, "bridge locked before tool")
	e.accept("tool")
	e.on_gain({"wood": 2}); t.ok(not e.is_ready("tool"))
	e.on_gain({"wood": 1, "fragment": 1}); t.ok(e.is_ready("tool"))
	t.eq(e.turn_ins_for("percival").map(func(q): return q.id), ["tool"], "turn in to the Sindaco")
	t.eq(int(e.complete("tool").harmony), 10, "reward")
	e.accept("bridge")
	t.eq([e.stage_index("bridge"), e.stages("bridge").size()], [1, 3], "the bridge comes in three steps")
	built[0] = true   # built before its step comes up: it waits its turn
	var ev := e.refresh()
	t.ok(not ev.any(func(x): return x.has("objective") and x.objective.id == "build"), "the building step isn't reported early")
	built[0] = false
	e.on_gain({"wood": 6})
	t.eq(e.current_stage("bridge"), 0, "still gathering")
	t.eq(e.next_step("bridge").objective.id, "wood", "next: more wood")
	e.on_gain({"wood": 4})
	t.eq(e.current_stage("bridge"), 1, "materials done: now build")
	t.ok(e.shown_objectives("bridge").later == 1, "the railings step stays hidden until then")
	built[0] = true
	e.refresh()
	t.eq(e.current_stage("bridge"), 2, "bridge built: now railings")
	t.ok(not e.is_ready("bridge"), "railings still to do")
	for i in 4: s.placements.append({"uid": 50 + i, "id": "railing", "i": float(-1 + (i % 2) * 2), "k": float(-16 - i), "r": 1, "y": 0.0})
	ev = e.refresh()
	t.ok(ev.any(func(x): return x.has("ready")), "four railings on the bridge: ready")
	built[0] = false
	t.ok(e.is_ready("bridge"), "build objective latched")
	t.eq(e.next_step("bridge").npc, "fern", "next step")

func test_stages_gate_gathering_and_talks():
	var s := GameState.new_game()
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}}
	var e := QuestEngine.new(s)
	e.accept("workshop")
	e.on_talk("bram")
	t.ok(not e.objective("workshop", Data.quest("workshop").objectives[3]).done, "talking to Bram early doesn't skip the materials")
	e.on_gain({"wood": 10, "metal": 2, "crystal": 1})
	t.eq(e.next_step("workshop").get("npc", ""), "bram", "materials gathered: go and talk to Bram")
	var ev := e.on_talk("bram")
	t.ok(ev.any(func(x): return x.has("objective") and x.objective.id == "plan"), "talking to him completes that step")
	t.eq(e.current_stage("workshop"), 2, "then furnish")
	e.on_gain({"wood": 50})
	t.eq(int(s.quests.workshop.progress.wood), 10, "gathering after its step doesn't keep counting")

func test_pay_for_the_deed():
	var s := GameState.new_game()
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}}
	var e := QuestEngine.new(s)
	e.accept("home")
	t.eq(e.payments_for("percival").size(), 1, "Percival is waiting for the deed money")
	var opts: Array = Conversation.build(Data.npc("percival"), e, s.flags, "Pip").options
	t.ok(opts.any(func(o): return o.kind == "pay" and o.id == "home"), "his conversation offers to pay")
	var r := e.pay("home", "deed")
	t.ok(not r.ok and r.missing[0].id == "coins" and r.missing[0].need == 100, "not enough coins: says how many are missing")
	s.inventory["coins"] = 130
	r = e.pay("home", "deed")
	t.ok(r.ok and Shop.coins(s) == 30, "paid 100 coins")
	t.ok(r.newly.any(func(x): return x.has("objective") and x.objective.id == "deed"), "the deed step is reported (its onDone opens the plot)")
	t.eq(e.current_stage("home"), 1, "then build the house")
	t.ok(e.payments_for("percival").is_empty() and not e.pay("home", "deed").ok, "you only pay once")

func test_conversation():
	var s := GameState.new_game()
	var e := QuestEngine.new(s)
	var c := Conversation.build(Data.npc("percival"), e, s.flags, "Pip")
	t.eq(c.main_offer.get("id", ""), "tool", "main offer")
	s.quests["tool"] = {"status": "done", "progress": {}}; s.quests["bridge"] = {"status": "done", "progress": {}}
	c = Conversation.build(Data.npc("percival"), e, s.flags, "Pip")
	t.eq(c.main_offer.get("id", ""), "decree")
	t.ok(c.options.any(func(o): return o.kind == "offer" and o.id == "stones"), "side quest choice")
	t.eq(c.options.back().kind, "bye")
	t.ok(not "{name}" in c.greeting)

func test_schedule_and_paths():
	t.eq(Schedule.activity_at(Data.npc("fern"), 8 * 60, {}).node, "fernGarden")
	t.eq(Schedule.activity_at(Data.npc("fern"), 13 * 60, {"orchardOpen": true}).node, "orchard")
	t.eq(Schedule.activity_at(Data.npc("fern"), 23 * 60, {}).activity, "sleep")
	t.eq(Schedule.activity_at(Data.npc("percival"), 9 * 60, {}).node, "westGate", "the Sindaco waits at the gate for the new Geometra")
	t.eq(Schedule.activity_at(Data.npc("percival"), 9 * 60, {"toolGiven": true}).node, "castle:spot", "then goes back to the town hall")
	t.eq(Schedule.find_path("squareN", "orchard", {}), [], "no path without the bridge")
	var p := Schedule.find_path("squareN", "orchard", {"orchardOpen": true})
	t.ok(p.has("bridgeS") and p.has("bridgeN"), str(p))

func test_clock():
	var c := {"day": 1, "minute": 480.0, "total": 0.0}
	Clock.advance(c, 60 * 14); t.ok(Clock.is_night(c))
	t.eq(Clock.text(c), "Day 1 · 10:00 PM")
	Clock.sleep_until_morning(c); t.eq([int(c.day), int(c.minute)], [2, 420])
	t.eq(Clock.weather({"day": 1, "minute": 600.0}), "sunny")

func test_minigames():
	var g := Minigames.Chop.new(Rng.new(4))
	for n in 4000:
		if g.done: break
		g.step(1.0 / 60.0, g.pause <= 0.0 and absf(g.needle() - g.center) < 0.02)
	t.ok(g.done and g.results.all(func(r): return r != "miss"), str(g.results))
	var idle := Minigames.Mine.new(false, Rng.new(3))
	for n in 4000:
		if idle.done: break
		idle.step(1.0 / 60.0, false)
	t.eq(idle.results, ["miss", "miss", "miss"]); t.eq(int(idle.reward().stone), 1)
	var f := Minigames.Fish.new(Rng.new(5))
	for n in 8000:
		if f.done: break
		f.step(1.0 / 60.0, f.phase == "bite", f.phase == "reel" and f.tension < 0.5)
	t.eq(f.result, "caught")
	var early := Minigames.Fish.new(Rng.new(1)); early.step(0.1, true); t.eq(early.result, "early")

func test_minigames_judge_what_is_shown():
	# A press judges the needle/ring where it was drawn, even at a low frame rate (big dt), and the result stays
	# on screen during the pause instead of jumping to the next round.
	var c := Minigames.Chop.new(Rng.new(7))
	c.phase = asin((c.center + c.width / 2.0 - 0.01) * 2.0 - 1.0)   # needle just inside the green edge
	var shown := c.needle()
	c.step(0.1, true)
	t.eq(c.last, "good", "needle shown inside the green counts (needle at %.3f, zone %.3f ± %.3f)" % [shown, c.center, c.width / 2.0])
	t.ok(absf(c.hit_at - shown) < 0.0001 and c.pause > 0.0, "the hit is shown where it landed during the pause")
	var center_before := c.center
	c.step(0.3, false)
	t.eq(c.center, center_before, "the zone doesn't move until the pause is over")
	var m := Minigames.Mine.new(false, Rng.new(2))
	m.r = m.target[1] - 0.005
	m.step(0.1, true)
	t.ok(m.last != "miss", "ring shown inside the band counts (%s)" % m.last)
	var m2 := Minigames.Mine.new(false, Rng.new(2))
	m2.r = m2.target[1] + 0.06
	m2.step(0.016, true)
	t.eq(m2.last, "miss", "ring clearly outside the band misses")

func test_gardening():
	var gd := {}
	t.eq(Gardening.action(gd, "bed0", {"seeds": 1}), "plant")
	Gardening.plant(gd, "bed0", 0); Gardening.water(gd, "bed0", 0)
	Gardening.grow(gd, Gardening.GROW_MINUTES); t.eq(int(gd.bed0.stage), 1)
	for s in 2: Gardening.water(gd, "bed0", (s + 2) * 1000.0); Gardening.grow(gd, (s + 2) * 1000.0 + Gardening.GROW_MINUTES)
	t.eq(Gardening.action(gd, "bed0", {}), "harvest")
	t.eq(int(Gardening.harvest(gd, "bed0").pumpkin), 2, "the beds grow pumpkins")

func test_save_round_trip():
	var st := GameState.new_game("Pip", {"hair": "curly", "hat": "crown"})
	st.inventory["wood"] = 7; st.harmony = 88; st.flags["orchardOpen"] = true
	st.quests["bridge"] = {"status": "done", "progress": {"build": 1}}
	st.placements.append({"uid": 4, "id": "bridgeDeck", "i": 0.0, "k": -16.0, "r": 0, "y": 0.0})
	st.placements.append({"uid": 9, "id": "lever", "i": 3.0, "k": 2.0, "r": 1, "y": 0.0, "state": {"on": false}, "color": "#7bd389"})
	st.relationships["fern"] = {"hearts": 5}
	var back := SaveSystem.deserialize(SaveSystem.serialize(st))
	t.eq(back.name, "Pip"); t.eq(back.inventory.wood, 7); t.eq(back.harmony, 88); t.ok(back.flags.orchardOpen)
	t.eq(back.quests.bridge.status, "done"); t.eq(back.placements.size(), 2); t.eq(back.placements[1].state.on, false)
	t.eq(back.placements[1].color, "#7bd389"); t.eq(back.next_uid, 10); t.eq(back.appearance.hair, "curly")
	var junk := SaveSystem.deserialize(JSON.stringify({"placements": [{"uid": 1, "id": "laserCannon", "i": 0, "k": 0, "y": 0}, {"uid": 2, "id": "floor", "i": 1, "k": 1, "y": 0, "r": 5}], "appearance": {"hair": "mohawk"}}))
	t.eq(junk.placements.size(), 1); t.eq(junk.placements[0].r, 1); t.eq(junk.appearance.hair, "bob")
	t.ok(SaveSystem.deserialize("null").is_empty())

func test_story_lead_survives_side_requests():
	# After the Sindaco's welcome, Gigia's story request waits; taking a side request must not hide it.
	var s := GameState.new_game("Ann")
	s.tutorial.on = false
	var e := QuestEngine.new(s)
	s.quests["tool"] = {"status": "active", "progress": {}, "done": {}}
	s.tracked = "tool"
	e.complete("tool")
	t.eq(s.tracked, "lead:bridge", "finishing the Sindaco's welcome heads for Gigia's request")
	t.ok(e.story_leads().map(func(q): return q.id).has("bridge"), "Fern's request is a story lead")
	e.accept("stones")
	t.eq(s.tracked, "lead:bridge", "taking Percival's side request keeps following the story")
	t.ok(e.story_leads().map(func(q): return q.id).has("bridge"), "and the story lead is still there")
	e.accept("bridge")
	t.eq(s.tracked, "bridge", "starting Fern's request follows it")
	t.eq(e.story_leads().size(), 0, "no lead while the story request is active")
	s.tracked = "stones"
	e.complete("stones")
	t.eq(s.tracked, "bridge", "finishing a side request goes back to the story")

func test_home_of_your_own():
	var q := Data.quest("home")
	t.ok(not q.is_empty() and q.giver == "percival" and q.requires.quests == ["bridge"], "Percival offers a home after the bridge")
	t.eq(Data.zone("plot").unlock, {"flag": "homePlot"}, "the plot opens with the deed, not at the start")
	var deed: Dictionary = q.objectives[0]
	t.ok(deed.kind == "pay" and int(deed.items.get("coins", 0)) > 0 and "homePlot" in deed.onDone.flags, "the plot opens once you've paid for the deed")
	t.ok("bed" in deed.onDone.blueprints and "roof" in deed.onDone.blueprints and int(deed.onDone.items.get("fabric", 0)) >= 2, "the deed comes with the blueprints and fabric for a bed and roof")
	var home_needs: Array = q.objectives[1].needs
	var z := Data.zone("plot")
	var pls: Array = []
	var add := func(id: String, i: int, k: int) -> void: pls.append({"uid": pls.size() + 1, "id": id, "i": float(i), "k": float(k), "r": 0, "y": 0.0})
	add.call("woodWall", 19, 10); add.call("woodWall", 20, 10); add.call("doorWall", 21, 10)
	t.ok(not Validate.room_checklist(z, pls, home_needs).all(func(r): return r.ok), "not a home yet: missing a wall, roof and bed")
	add.call("windowWall", 19, 11); add.call("roof", 19, 11); add.call("bed", 22, 12)
	t.ok(Validate.room_checklist(z, pls, home_needs).all(func(r): return r.ok), "3 walls, a door, a roof and a bed make a home")
	t.ok(Data.layout.buildings.any(func(b): return b.id == "playerHouse" and b.get("inn", false) and b.name == "The Lantern Inn"), "you start out at the Lantern Inn")

func test_live_checks_are_cached_until_something_changes():
	# villagers' markers, the compass and the tracker ask every frame; the bridge's path search runs once a frame
	var s := GameState.new_game()
	s.quests["tool"] = {"status": "done", "progress": {}}
	var calls := [0]
	var check := func():
		calls[0] += 1
		return false
	var e := QuestEngine.new(s, {"bridge": check})
	e.accept("bridge")
	e.on_gain({"wood": 10})
	calls[0] = 0
	for i in 20:
		e.next_step("bridge"); e.is_ready("bridge"); e.current_stage("bridge"); e.shown_objectives("bridge")
	t.ok(calls[0] <= 1, "asked 80 times, checked %d time(s)" % calls[0])
	var before: int = calls[0]
	e.invalidate()
	e.is_ready("bridge")
	t.eq(calls[0], before + 1, "checked again after invalidating (a new frame)")

func test_some_requests_keep_hours():
	t.ok(Clock.in_hours([5, 10], 6 * 60.0) and not Clock.in_hours([5, 10], 11 * 60.0), "5 AM to 10 AM")
	t.ok(Clock.in_hours([20, 4], 23 * 60.0) and Clock.in_hours([20, 4], 2 * 60.0) and not Clock.in_hours([20, 4], 12 * 60.0), "windows wrap past midnight")
	var timed: Array = Data.quests.filter(func(q): return q.has("hours"))
	t.ok(timed.size() >= 3 and timed.size() < Data.quests.size() / 2, "a few requests keep hours, not most (%d)" % timed.size())
	t.ok(not timed.any(func(q): return q.get("main", false)), "story requests are never hidden by the clock")
	var s := GameState.new_game()
	for q in ["tool", "bridge", "decree"]: s.quests[q] = {"status": "done", "progress": {}}
	var e := QuestEngine.new(s)
	s.time.minute = 14 * 60.0
	t.ok(not e.can_offer("catch"), "the Captain doesn't offer his fishing request in the afternoon")
	t.ok(e.later_for("captain").any(func(q): return q.id == "catch"), "...but you can tell he will, at dawn")
	var opts: Array = Conversation.build(Data.npc("captain"), e, s.flags, "Pip").options
	t.ok(opts.any(func(o): return o.kind == "later" and o.id == "catch" and "5 AM" in o.label), "his conversation says when to come back")
	s.time.minute = 6 * 60.0
	t.ok(e.can_offer("catch") and e.later_for("captain").is_empty(), "at 6 AM he asks")

func test_steps_with_hours_count_only_then():
	var s := GameState.new_game()
	s.island = "clockwork"
	for q in ["tool", "bridge", "workshop", "decree", "dock", "cove"]: s.quests[q] = {"status": "done", "progress": {}}
	s.quests["lighthouse"] = {"status": "active", "progress": {"wood": 8, "metal": 2, "light": 1}, "done": {}}
	var e := QuestEngine.new(s)
	t.eq(e.current_stage("lighthouse"), 2, "lighthouse lit: now watch it with Juniper")
	s.time.minute = 15 * 60.0
	e.on_talk("juniper")
	t.ok(not e.is_ready("lighthouse"), "in the afternoon it doesn't count")
	s.time.minute = 21 * 60.0
	e.on_talk("juniper")
	t.ok(e.is_ready("lighthouse"), "at 9 PM it does")

func test_sleep_until_a_chosen_hour():
	var t0 := {"day": 1, "minute": 15 * 60.0, "total": 900.0}
	var slept := Clock.sleep_until(t0, 21.0)
	t.ok(t0.day == 1 and t0.minute == 21 * 60.0 and slept == 360.0, "a nap until the evening, same day")
	slept = Clock.sleep_until(t0, 6.0)
	t.ok(t0.day == 2 and t0.minute == 360.0 and slept == 540.0 and t0.total == 900.0 + 360.0 + 540.0, "then through the night to 6 AM")
	slept = Clock.sleep_until(t0, 6.0)
	t.ok(t0.day == 3 and slept == 1440.0, "asking for the hour it already is sleeps a whole day round")
