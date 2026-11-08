extends RefCounted
var t

func test_a_new_game_has_no_metal_detector():
	t.ok(not WorldActions.has_detector(GameState.new_game()), "the Geometra's kit doesn't come with a metal detector")

func test_fede_hands_over_the_detector_when_you_take_on_his_request():
	t.ok(Data.quest("treasure").get("onAccept", {}).get("flags", []).has(WorldActions.DETECTOR), "Beep, Beep gives the metal detector when accepted")

func test_every_request_that_sends_you_digging_gives_the_detector():
	var digs_by_island := {}
	for i in Data.islands:
		if not Data.has_island(i.id): continue
		digs_by_island[i.id] = Data.read_layout(i.id).get("nodes", []).filter(func(n): return n.kind == "dig")
	var checked := 0
	for q in Data.quests:
		var digs: Array = digs_by_island.get(Data.quest_island(q.id), [])
		if digs.is_empty(): continue
		var accept_flags: Array = q.get("onAccept", {}).get("flags", [])
		var dug_items := {}
		for n in digs:
			for k in n.get("gives", {}): dug_items[k] = true
		var uses := digs.any(func(n): return n.has("flag") and accept_flags.has(n.flag))
		for o in q.get("objectives", []):
			if o.kind == "event" and String(o.get("event", "")) in ["dig", "treasure"]: uses = true
			if o.kind == "gather" and dug_items.has(String(o.get("item", ""))) and String(o.item) != "coins": uses = true
		if not uses: continue
		checked += 1
		t.ok(accept_flags.has(WorldActions.DETECTOR), "%s sends you digging, so it gives the metal detector when accepted" % q.id)
	t.ok(checked >= 3, "Beep, Beep, Matteo's museum and the Roman finds are among the requests that send you digging (%d)" % checked)

func test_an_old_save_with_fedes_request_taken_on_has_the_detector():
	var s := GameState.new_game()
	s.quests["treasure"] = {"status": "active", "progress": {}, "done": {}}
	t.ok(WorldActions.has_detector(SaveSystem.deserialize(SaveSystem.serialize(s))), "a save from before the detector was its own thing keeps it once Fede has handed it over")
	var fresh := GameState.new_game()
	t.ok(not WorldActions.has_detector(SaveSystem.deserialize(SaveSystem.serialize(fresh))), "a save where Fede hasn't asked yet has no detector")
