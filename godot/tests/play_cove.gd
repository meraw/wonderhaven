extends "res://tests/full_base.gd"
## Clockwork Cove with real input: board Hearthglow's ferry after the dock is rebuilt, sail to the cove, meet its
## three villagers, light the lighthouse with a windmill, get the old clock ticking with a waterwheel, trade at
## Hazel's forge, then sail home and find Hearthglow as you left it.
## Run: TIMEOUT=6000 ./play.sh res://tests/play_cove.gd /tmp/out

func eng() -> QuestEngine: return game.story.engine

## Opens a villager's shop from their conversation and buys an item bundle until `done` holds (or coins run out).
func buy_at(id: String, item: String, done: Callable) -> void:
	var a = game.npcs[id]
	for attempt in 4:
		await walk_to(a.pos.x, a.pos.z, 1.5)
		if await face_and_press("npc:" + id, a.pos.x, a.pos.z): break
	for n in 120:
		await frames(4)
		if game.panels.current == "shop": break
		var ui: DialogueUI = game.dialogue
		if game.mode == "dialogue" and not ui.choices.is_empty():
			var i: int = ui.choices.map(func(o): return o.get("kind", "")).find("shop")
			if i < 0: i = ui.choices.map(func(o): return o.get("kind", "")).find("no")
			await tap(KEY_1 + maxi(0, i))
		elif game.mode == "dialogue": await tap(KEY_E)
	note("shop open: %s" % (game.panels.current == "shop"))
	var lines: Array = Shop.stock(game.state, id).filter(func(e): return e.kind == "items" and e.items.has(item))
	for k in 4:
		if done.call() or lines.is_empty(): break
		var b := game.panels.find_child("buy_%d" % lines[0].i, true, false) as Button
		if b == null or b.disabled: break
		await click(b.get_global_rect().get_center()); await frames(8)
	await tap(KEY_ESCAPE); await frames(10)

func play() -> void:
	# Hearthglow, after its story: the harbor is open and the dock rebuilt
	var s: Dictionary = game.state
	for qid in ["tool", "bridge", "workshop", "fountain", "decree", "dock"]: s.quests[qid] = {"status": "done", "progress": {}, "done": {}}
	for f in ["hasTool", "toolGiven", "orchardOpen", "workshopDone", "harborOpen", "boatReady", "clockworkRevealed", "fountainRestored"]: s.flags[f] = true
	s.tutorial = Tutorial.new_state(false, true); s.harmony = 140
	s.inventory = {"spark": 20, "coins": 30}
	game.player_char.show_staff(true)
	for k in range(41, 50):
		var pl := {"uid": int(s.next_uid), "id": "bridgeDeck", "i": 5.0, "k": float(k), "r": 0, "y": BuildGrid.suggest_bottom("bridgeDeck", 5, k, 0, 0.15, s.placements, Data.zone("dock"))}
		game.commit_place(pl, false, false)
	game.hud.apply_reveals(); game.render_resources(); game.hud.render_harmony(); game.hud.render_tracker()
	s.time.minute = 9 * 60.0
	var dock_pieces: int = s.placements.size()
	game.player.teleport(5.5, 48.5, 0.0); game.cam.snap(); await frames(10)
	await walk_direct(5.5, 49.6, 0.5)
	await face_and_press("boat", 5.5, 51.6); await frames(10)
	check("c1", "Boarding the ferry opens the map with Clockwork Cove revealed", game.panels.current == "map" and game.panels.find_child("map_view", true, false) != null, game.panels.current)
	await shot("map")
	var ok := await sail("clockwork")
	await shot("arrival")
	s = game.state
	check("c2", "Sailing loads Clockwork Cove: its own ground, buildings and villagers, nothing of Hearthglow's built here", ok and Data.island == "clockwork" and s.placements.is_empty() and game.village.objects.has("lighthouse") and game.npcs.has("barnaby") and not game.npcs.has("odessa"),
		"island %s, pieces %d, villagers %s" % [Data.island, s.placements.size(), game.npcs.keys()])
	check("c3", "Barnaby has the next story request waiting", game.story.marker_for("barnaby") == "offer" and eng().story_leads().any(func(q): return q.id == "cove"), game.story.marker_for("barnaby"))
	# Welcome to the Cove: meet the neighbours
	await talk("barnaby")
	check("c4", "Accepted Barnaby's welcome", eng().status("cove") == "active", eng().status("cove"))
	await talk("juniper"); await talk("hazel")
	check("c5", "Meeting Juniper and Hazel are request steps of their own", eng().is_ready("cove"), str(s.quests.get("cove", {})))
	await talk("barnaby")
	check("c6", "Barnaby's welcome is complete (windmill, shaft and gear plans)", eng().is_done("cove") and s.blueprints.has("windmill") and s.blueprints.has("gear"), eng().status("cove"))
	# Light the Lighthouse: materials, then a windmill on the cape
	await talk("juniper")
	check("c7", "Juniper asks for help with the lighthouse", eng().status("lighthouse") == "active", eng().status("lighthouse"))
	await gather_until("chop", func(): return int(q("lighthouse").progress.get("wood", 0)) >= 8 and inv("wood") >= 7 and inv("spark") >= 4, [], 20)
	await gather_until("mine", func(): return int(q("lighthouse").progress.get("metal", 0)) >= 2 and inv("metal") >= 2, ["cove_rock0", "cove_rock1", "cove_rock2", "cove_rock3"], 16)
	print("   lighthouse materials: ", s.inventory, " step ", eng().stage_index("lighthouse"))
	check("c8", "Materials gathered: the building step opens", eng().current_stage("lighthouse") == 1, "step %d" % eng().stage_index("lighthouse"))
	await walk_to(-23.5, -12.6, 1.0)
	await open_build("lighthouse")
	await shot("lighthouse-build")
	await select_piece("windmill"); print("   windmill: ", await place_at(-21, -20, 1.3, 0))
	await select_piece("gear"); print("   gear: ", await place_at(-21, -19, 1.3, 0))
	await select_piece("shaft"); print("   shaft: ", await place_at(-22, -19, 1.3, 1))
	await select_piece("gear"); print("   gear: ", await place_at(-23, -19, 1.3, 0))
	await frames(10)
	check("c9", "Windmill → gear → shaft → gear powers the lighthouse's drive", game.mech.fed.get("lighthouse", false) and eng().is_ready("lighthouse"), "fed=%s pieces=%d" % [game.mech.fed.get("lighthouse", false), s.placements.size()])
	await leave_build()
	s.time.minute = 21.5 * 60.0
	await frames(40)
	var beam: Node3D = game.village.objects.lighthouse.get_node("beam")
	game.cam.yaw = 0.4; game.cam.pitch = 0.25; game.cam.dist = 14.0
	await frames(30)
	await shot("lighthouse-night")
	check("c10", "At night the lighthouse beam sweeps the bay", beam.visible, "beam visible=%s" % beam.visible)
	s.time.minute = 9 * 60.0
	await talk("juniper")
	check("c11", "The lighthouse request is done", eng().is_done("lighthouse") and s.flags.get("lighthouseLit", false), eng().status("lighthouse"))
	# The Stopped Clock: parts for Barnaby, then a waterwheel in the millrace
	await talk("barnaby")
	check("c12", "Barnaby asks about his clock", eng().status("clocktower") == "active", eng().status("clocktower"))
	var enough := func(): return int(q("clocktower").progress.get("metal", 0)) >= 3 and int(q("clocktower").progress.get("crystal", 0)) >= 1 and inv("metal") >= 3 and inv("crystal") >= 1
	await gather_until("mine", enough, [], 8)
	if not enough.call():   # the rocks are regrowing: buy the rest at Hazel's forge
		await buy_at("hazel", "metal", func(): return int(q("clocktower").progress.get("metal", 0)) >= 3 and inv("metal") >= 3)
		check("c12b", "Short of metal, you can buy it at Hazel's forge on the cove", inv("metal") >= 3, "metal %d, coins %d" % [inv("metal"), inv("coins")])
	note("clock materials: %s" % str(s.inventory))
	await talk("barnaby")
	check("c13", "Handing Barnaby the parts in conversation (a pay step)", eng().current_stage("clocktower") == 2 and s.flags.get("clockParts", false), "step %d" % eng().stage_index("clocktower"))
	await gather_until("chop", func(): return inv("wood") >= 7 and inv("spark") >= 4, [], 16)
	await walk_to(5.6, -10.2, 1.0)
	await open_build("clockyard")
	await select_piece("waterwheel"); print("   waterwheel: ", await place_at(12, -8, -0.3, 0))
	await select_piece("shaft"); print("   shaft: ", await place_at(12, -9, 0.2, 0)); print("   shaft: ", await place_at(12, -10, 0.2, 0))
	await select_piece("gear"); print("   gear: ", await place_at(12, -11, 0.2, 0))
	await frames(10)
	check("c14", "Waterwheel → shafts → gear drives the clock", game.mech.fed.get("clock", false) and eng().is_ready("clocktower"), "fed=%s" % game.mech.fed.get("clock", false))
	await leave_build()
	game.cam.yaw = 0.2; game.cam.pitch = 0.3; game.cam.dist = 12.0
	await frames(30)
	await shot("clock-ticking")
	await talk("barnaby")
	check("c15", "The clock request is done: Clockwork Cove's story so far is complete", eng().is_done("clocktower") and s.flags.get("clockRunning", false), eng().status("clocktower"))
	# Hazel's shop is open on this island too
	var hz = game.npcs.hazel
	var opts: Array = Conversation.build(hz.def, eng(), s.flags, s.name).options
	check("c16", "Hazel trades at her forge", opts.any(func(o): return o.kind == "shop") and Shop.is_open(s, "hazel"), str(opts.map(func(o): return o.kind)))
	# Sail home
	var cove_pieces: int = s.placements.size()
	var b: Dictionary = {}
	for f in Data.layout.features:
		if f.id == "boat": b = f
	await walk_to(2, 28.4, 1.0)
	await walk_direct(b.x - 0.6, 30.6, 0.5)
	await face_and_press("boat", b.x, b.z); await frames(10)
	ok = await sail("hearthglow")
	await shot("home")
	s = game.state
	check("c17", "Sailing home: Hearthglow's dock is still there and the cove's machines wait on the cove", ok and Data.island == "hearthglow" and s.placements.size() == dock_pieces and s.away.get("clockwork", {}).get("placements", []).size() == cove_pieces and game.npcs.has("odessa"),
		"island %s, pieces %d (dock %d), cove pieces %d" % [Data.island, s.placements.size(), dock_pieces, s.away.get("clockwork", {}).get("placements", []).size()])
	var back := SaveSystem.deserialize(SaveSystem.serialize(game.snapshot()))
	check("c18", "The save keeps both islands", back.island == "hearthglow" and back.away.clockwork.placements.size() == cove_pieces and back.quests.clocktower.status == "done", "")
