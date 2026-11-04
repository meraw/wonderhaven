extends RefCounted
## The guided first day: step data, advancing, HUD reveals, request gating, saves.
var t

func test_tutorial_data_is_valid():
	var ids := {}
	for st in Tutorial.steps():
		t.ok(st.has("id") and st.has("text") and st.has("done"), "step %s has id, text and done" % st.get("id", "?"))
		t.ok(not ids.has(st.id), "step ids are unique (%s)" % st.id); ids[st.id] = true
		var tg: String = st.get("target", "")
		if tg.begins_with("npc:"): t.ok(not Data.npc(tg.trim_prefix("npc:")).is_empty(), "%s targets a real villager" % st.id)
		if tg.begins_with("zone:"): t.ok(not Data.zone(tg.trim_prefix("zone:")).is_empty(), "%s targets a real zone" % st.id)
		var d: PackedStringArray = String(st.done).split(":")
		if d[0] in ["accepted", "quest", "ready", "objective", "stage"]: t.ok(not Data.quest(d[1]).is_empty(), "%s waits on a real quest" % st.id)
		if d[0] == "stage": t.ok(int(d[2]) < QuestEngine.new(GameState.new_game()).stages(d[1]).size(), "%s waits on a real step" % st.id)
		if d[0] == "objective": t.ok(int(d[2]) < Data.quest(d[1]).objectives.size(), "%s waits on a real objective" % st.id)
		if d[0] == "panel": t.ok(d[1] in ["inventory", "journal", "map", "progress"], "%s waits on a real panel" % st.id)
	for q in Data.tutorial.offers: t.ok(Data.quest(q).get("main", false), "guided offers are main quests (%s)" % q)
	for id in Data.tutorial.tips: t.ok(Data.tutorial.tips[id].has("title") and Data.tutorial.tips[id].lines.size() > 0, "tip %s has a title and lines" % id)

func test_steps_advance_in_order_and_finish():
	var s := Tutorial.new_state(true)
	var facts := {"moved": 0.0, "looked": 0.0, "flags": {}, "panels": [], "quests": {}}
	t.eq(Tutorial.advance(s, facts), [], "nothing done yet")
	t.eq(Tutorial.current(s).id, "walk", "starts with walking")
	facts.looked = 2.0
	t.eq(Tutorial.advance(s, facts), [], "looking around early doesn't skip walking")
	facts.moved = 5.0
	t.eq(Tutorial.advance(s, facts), ["walk", "look"], "walking, then the look step already done, both complete")
	t.eq(Tutorial.current(s).id, "talk", "then talk to the Sindaco")
	facts.flags = {"toolGiven": true}; facts.quests = {"tool": {"status": "active"}}
	facts["objective"] = func(q, i): return i == 0
	t.eq(Tutorial.advance(s, facts), ["talk", "chop"], "accepting the tool and having the wood")
	t.eq(Tutorial.current(s).id, "bag", "then open the bag")
	facts.panels = ["inventory", "journal"]
	facts.quests = {"tool": {"status": "done"}, "bridge": {"status": "done"}}
	facts.buildmode = true
	Tutorial.advance(s, facts)
	t.ok(not s.on, "everything done switches the guided day off")
	t.eq(Tutorial.current(s), {}, "no current step afterwards")

func test_story_progress_skips_learning_steps():
	var s := Tutorial.new_state(true)
	var facts := {"moved": 5.0, "looked": 1.0, "flags": {"toolGiven": true}, "panels": [], "quests": {"tool": {"status": "done"}}}
	Tutorial.advance(s, facts)
	t.eq(Tutorial.current(s).id, "journal", "finishing the welcome request skips the bag step nobody did")
	facts.quests["bridge"] = {"status": "done"}
	Tutorial.advance(s, facts)
	t.ok(not s.on, "finishing the bridge ends the guided day even if the journal was never opened")
	var early := Tutorial.new_state(true)
	Tutorial.advance(early, {"moved": 0.0, "looked": 0.0, "flags": {}, "panels": ["journal", "inventory"], "quests": {}})
	t.eq(Tutorial.current(early).id, "walk", "opening menus early doesn't skip ahead")

func test_reveals_and_gating():
	var s := Tutorial.new_state(true)
	t.ok(not Tutorial.revealed(s, "harmony"), "approval bar hidden at first")
	t.ok(not Tutorial.revealed(s, "key:journal"), "journal key hidden at first")
	t.ok(Tutorial.allows_offer(s, "tool") and not Tutorial.allows_offer(s, "stones"), "only the guided requests are offered")
	s.step = Tutorial.steps().map(func(x): return x.id).find("return")
	t.ok(Tutorial.revealed(s, "harmony") and Tutorial.revealed(s, "resources"), "earlier reveals stay revealed")
	s.on = false
	t.ok(Tutorial.revealed(s, "key:map") and Tutorial.allows_offer(s, "stones"), "everything opens when the guided day is off")

func test_fill_uses_current_keys():
	var out := Tutorial.fill("Walk with {move}, press {interact}.", func(a): return {"move_forward": "W", "move_left": "A", "move_back": "S", "move_right": "D", "interact": "E"}.get(a, "?"))
	t.eq(out, "Walk with WASD, press E.", "placeholders become key names")

func test_old_saves_skip_the_guided_day():
	var old := GameState.new_game("Ann")
	old.erase("tutorial")
	var s := SaveSystem.deserialize(JSON.stringify(old))
	t.ok(not s.tutorial.on, "a save from before the tutorial doesn't start it")
	t.eq(s.tutorial.seen.size(), Data.tutorial.tips.size(), "and doesn't show tips for things already known")
	var fresh := GameState.new_game("Bo")
	fresh.tutorial.step = 3; fresh.tutorial.panels = ["inventory"]
	var back := SaveSystem.deserialize(JSON.stringify(fresh))
	t.ok(back.tutorial.on and back.tutorial.step == 3 and back.tutorial.panels == ["inventory"], "tutorial progress survives saving")

func test_stage_steps():
	var step := {"done": "stage:bridge:1"}
	var facts := {"quests": {"bridge": {"status": "active"}}, "stage": func(q): return 0}
	t.ok(not Tutorial.is_done(step, facts), "still gathering for the bridge")
	facts.stage = func(q): return 1
	t.ok(Tutorial.is_done(step, facts), "materials gathered")
	t.ok(Tutorial.is_done(step, {"quests": {"bridge": {"status": "done"}}}), "a finished request counts as past every step")
