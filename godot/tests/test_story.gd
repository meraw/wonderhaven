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
		t.ok(Data.layout.nav_nodes.has(n.home), n.id)
		t.ok(Data.quests.any(func(q): return q.giver == n.id), "%s gives a quest" % n.id)

func test_quest_flow():
	var s := GameState.new_game()
	var built := [false]
	var e := QuestEngine.new(s, {"bridge": func(): return built[0]})
	t.eq(e.offers_for("fern").size(), 0, "bridge locked before tool")
	e.accept("tool")
	e.on_gain({"wood": 2}); t.ok(not e.is_ready("tool"))
	e.on_gain({"wood": 1, "fragment": 1}); t.ok(e.is_ready("tool"))
	t.eq(e.turn_ins_for("odessa").map(func(q): return q.id), ["tool"], "turn in")
	t.eq(int(e.complete("tool").harmony), 10, "reward")
	e.accept("bridge")
	e.on_gain({"wood": 6, "spark": 5})
	t.ok(not e.is_ready("bridge"), "needs the bridge")
	built[0] = true
	var ev := e.refresh()
	t.ok(ev.any(func(x): return x.has("ready")), "ready event")
	built[0] = false
	t.ok(e.is_ready("bridge"), "build objective latched")
	t.eq(e.next_step("bridge").npc, "fern", "next step")

func test_conversation():
	var s := GameState.new_game()
	var e := QuestEngine.new(s)
	var c := Conversation.build(Data.npc("odessa"), e, s.flags, "Pip")
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
	t.eq(Schedule.activity_at(Data.npc("odessa"), 9 * 60, {}).node, "westGate")
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

func test_gardening():
	var gd := {}
	t.eq(Gardening.action(gd, "bed0", {"seeds": 1}), "plant")
	Gardening.plant(gd, "bed0", 0); Gardening.water(gd, "bed0", 0)
	Gardening.grow(gd, Gardening.GROW_MINUTES); t.eq(int(gd.bed0.stage), 1)
	for s in 2: Gardening.water(gd, "bed0", (s + 2) * 1000.0); Gardening.grow(gd, (s + 2) * 1000.0 + Gardening.GROW_MINUTES)
	t.eq(Gardening.action(gd, "bed0", {}), "harvest")
	t.eq(int(Gardening.harvest(gd, "bed0").flowers), 3)

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
