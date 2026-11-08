extends "res://tests/full_base.gd"

var events: Array = []

func of(type: String) -> Array: return events.filter(func(e): return e.type == type)

func choices_up(id: String) -> void:
	var a = game.npcs[id]
	game.player.teleport(a.pos.x + 0.5, a.pos.z + 1.9, atan2(-0.5, -1.9)); game.cam.snap(); await frames(5)
	await tap(KEY_E)
	for n in 80:
		await frames(4)
		if not game.dialogue.choices.is_empty(): return
		if game.mode == "dialogue": await tap(KEY_E)

func pick(kind: String, id: String = "") -> bool:
	var i := -1
	for n in game.dialogue.choices.size():
		var c: Dictionary = game.dialogue.choices[n]
		if String(c.get("kind", "")) == kind and (id == "" or String(c.get("id", "")) == id): i = n; break
	if i < 0: return false
	await tap(game.dialogue.key_for(i))
	return true

func until_choices() -> void:
	for n in 80:
		await frames(4)
		if not game.dialogue.choices.is_empty() or game.mode != "dialogue": return
		await tap(KEY_E)

func put(id: String, i: float, k: float, r: int = 0) -> bool:
	var zone := BuildGrid.zone_at(game.placement_ctx().zones, i, k)
	var pl := {"uid": int(game.state.next_uid), "id": id, "i": i, "k": k, "r": r, "y": BuildGrid.suggest_bottom(id, i, k, r, 10.0, game.state.placements, zone)}
	game.state.next_uid = int(pl.uid) + 1
	var res: Dictionary = game.commit_place(pl, false, true)
	if not res.ok: note("%s at %d,%d: %s" % [id, i, k, res.get("reason", "")])
	return res.ok

func brief(qid: String) -> Dictionary:
	return Data.quest(qid).objectives.filter(func(o): return String(o.get("kind", "")) == "commission")[0]

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge", "workshop", "fountain", "home", "dock"]: s.quests[q] = {"status": "done", "progress": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen", "workshopDone", "fountainRestored", "boatReady"]: s.flags[fl] = true
	s.tutorial.on = false; game.hud.apply_reveals()
	for b in ["counter", "bookshelf", "lamp", "table", "chair", "hedge", "flowerBed"]:
		if not s.blueprints.has(b): s.blueprints.append(b)
	s.inventory.merge({"coins": 300, "wood": 60, "stone": 30, "flowers": 12, "crystal": 6}, true)
	s.time.minute = 10 * 60.0
	game.render_resources()
	for a in game.npcs.values(): a.teleport_home()
	game.game_event.connect(func(type, data): events.append({"type": type, "data": data}))
	await frames(10)

	await choices_up("mabel")
	var offered: bool = game.dialogue.choices.any(func(c): return String(c.get("id", "")) == "tables")
	await shot("ornella-asks-for-tables")
	await pick("offer", "tables")
	await until_choices()
	await pick("yes")
	for n in 40:
		await frames(4)
		if game.mode != "dialogue": break
		await tap(KEY_E)
	check("m1", "Ornella asks for tables outside the bakery, and taking it on follows it", offered and game.story.engine.status("tables") == "active", "offered %s, status %s" % [offered, game.story.engine.status("tables")])

	await walk_to(-11.0, 1.5, 1.0)
	await open_build("village")
	var goals: Dictionary = game.build_goals(game.build.current_zone)
	await shot("tables-brief-in-build-mode")
	check("m2", "In build mode the village streets show her brief: two tables, four seats, and two wishes", String(goals.get("title", "")) == "Tables Outside the Bakery" and goals.get("items", []).filter(func(it): return not it.get("wish", false)).size() == 2 and goals.get("items", []).filter(func(it): return it.get("wish", false)).size() == 2,
		"%s: %s" % [goals.get("title", ""), str(goals.get("items", []).map(func(it): return it.label))])
	var ticks0 := of("commission_tick").size()
	for e in brief("tables").plan: await put(String(e[2]), float(e[0]), float(e[1]), int(e[3]) if e.size() > 3 else 0)
	await frames(6)
	await shot("tables-built")
	check("m3", "Two tables and four chairs outside her door meet both musts, each ticking as it's met", game.story.engine.is_ready("tables") and of("commission_tick").size() - ticks0 >= 2, "ready %s, %d ticks" % [game.story.engine.is_ready("tables"), of("commission_tick").size() - ticks0])
	await leave_build()
	await talk("mabel")
	var stamp: Dictionary = s.quests.get("tables", {}).get("stamp", {})
	check("m4", "Handed in, her permit is stamped", s.quests.get("tables", {}).get("status", "") == "done" and String(stamp.get("text", "")) != "", str(stamp))

	game.story.engine.accept("stall")
	game.story.handle(game.story.engine.refresh())
	await put("counter", 18.0, 9.0)
	await put("hedge", 26.0, 12.0)
	await put("hedge", 27.0, 12.0)
	await frames(4)
	var apart: Dictionary = game.story.engine.commission("stall", brief("stall"))
	var apart_ok: bool = not apart.done and int(apart.met) == 1
	await put("hedge", 17.0, 9.0)
	await put("hedge", 20.0, 9.0)
	await frames(4)
	var together: Dictionary = game.story.engine.commission("stall", brief("stall"))
	check("m5", "Gigia's stall counts anywhere in the village, but only with its pieces together", apart_ok and game.story.engine.is_ready("stall") and together.uids.size() == 3,
		"apart: %d of 2 musts; together: ready %s, %d pieces" % [int(apart.met), game.story.engine.is_ready("stall"), together.uids.size()])

	game.story.engine.accept("stones")
	game.story.handle(game.story.engine.refresh())
	var staged: bool = game.story.engine.current_stage("stones") == 1
	for e in brief("stones").plan: await put(String(e[2]), float(e[0]), float(e[1]))
	await frames(4)
	var plinth: Dictionary = game.story.engine.commission("stones", brief("stones"))
	var face := atan2(3.0, -3.5)
	game.player.teleport(19.5, -2.5, face); game.cam.yaw = face + PI; game.cam.pitch = 0.45; game.cam.dist = 7.0; game.cam.snap()
	await frames(10)
	await shot("the-sindacos-plinth")
	check("m6", "With the stone gathered, three stacked blocks on the castle steps make the Sindaco's plinth, tall enough for his wish too", staged and game.story.engine.is_ready("stones") and plinth.wishes[0].ok,
		"stage ok %s, ready %s, taller-than-three %s" % [staged, game.story.engine.is_ready("stones"), plinth.wishes[0].ok])
