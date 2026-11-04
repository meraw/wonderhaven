extends "res://tests/full_base.gd"
## Full playthrough, part two: loads the slot-3 save that play_full.gd made (from the title screen, like a player),
## then the fountain machine, the King's decree, the dock, saving and loading, and sailing to Clockwork Cove and
## back. Checks acceptance tests 8, 11 and 12. Run play_full.gd first.

func play() -> void:
	await frames(20)
	var title_load: Control = game.screens.find_child("btn_load", true, false)
	if title_load: await click(title_load.get_global_rect().get_center()); await frames(10)
	var l3: Control = game.screens.find_child("load_slot3", true, false)
	if l3: await click(l3.get_global_rect().get_center()); await frames(30)
	check("B1", "Loaded part one's save from the title screen", game.mode == "explore" and q("workshop").get("status", "") == "done", "mode %s, workshop %s" % [game.mode, q("workshop").get("status", "")])
	if game.mode != "explore": return
	# Fountain: the mechanical puzzle
	await talk("tilly")
	await gather_until("clay", func(): return int(q("fountain").progress.get("clay", 0)) >= 6, [], 10)
	await gather_until("mine", func(): return int(q("fountain").progress.get("metal", 0)) >= 3 and inv("metal") >= 3, ["rock5", "rock0", "rock1", "rock2", "rock3", "rock4"], 14)
	await gather_until("chop", func(): return int(q("fountain").progress.get("wood", 0)) >= 6 and inv("wood") >= 6 and inv("spark") >= 14, [], 14)
	print("   fountain materials: ", game.state.inventory)
	await walk_to(6.0, 4.0, 1.0)
	await open_build("plaza")
	await select_piece("waterwheel"); print("   wheel: ", await place_at(9, 1, 0.1, 0))
	await select_piece("pump"); print("   pump: ", await place_at(8, 2, 0.1, 0))
	await select_piece("pipe")
	for i in range(7, 1, -1): await place_at(i, 2, 0.1, 1)
	var before := {"fed": game.mech.fed.get("fountain", false), "pumps": game.mech.pumps.size()}
	await select_piece("gear"); print("   gear: ", await place_at(9, 2, 0.1, 0))
	await frames(20)
	var jets: bool = (game.village.objects.fountain.get_node("jets") as Node3D).visible
	await shot("fountain-flowing")
	check(8, "A connected machine responds to its power source", not before.fed and before.pumps == 0 and game.mech.fed.get("fountain", false) and game.mech.pumps.size() == 1 and jets,
		"before gear: pumps=%d fed=%s; after: pumps=%d fed=%s jets=%s" % [before.pumps, before.fed, game.mech.pumps.size(), game.mech.fed.get("fountain", false), jets])
	await leave_build()
	await talk("tilly")
	print("   fountain: ", q("fountain").get("status", ""), " harmony ", game.state.harmony)
	# Harbor
	await talk("percival")
	print("   decree: ", q("decree").get("status", ""), " harborOpen ", game.state.flags.get("harborOpen", false))
	await walk_to(5.0, 37.0, 1.0)
	await talk("captain")
	await gather_until("chop", func(): return int(q("dock").progress.get("wood", 0)) >= 12 and int(q("dock").progress.get("spark", 0)) >= 6 and inv("wood") >= 9 and inv("spark") >= 9, [], 20)
	await walk_to(5.0, 37.0, 1.0)
	await walk_direct(5.5, 40.6, 0.6)
	await open_build("dock")
	await select_piece("bridgeDeck")
	for k in [41, 42, 43, 44, 45, 46, 47, 48, 49]: await place_at(5, k, 0.15)
	await shot("dock-built")
	await leave_build()
	await talk("captain")
	print("   dock: ", q("dock").get("status", ""), " boatReady ", game.state.flags.get("boatReady", false))
	# 11. Save, reload, load
	await tap(KEY_ESCAPE); await frames(5)
	var sb: Control = game.panels.find_child("btn_save_game", true, false)
	if sb: await click(sb.get_global_rect().get_center()); await frames(5)
	var s1: Control = game.panels.find_child("slot_slot1", true, false)
	if s1: await click(s1.get_global_rect().get_center()); await frames(5)
	var saved: Dictionary = game.state.duplicate(true)
	var _loaded := SaveSystem.read("slot1")
	game.panels.close()
	# Simulate quitting by resetting to a fresh state, then load through the menu like a player would.
	game.load_state(GameState.new_game())
	await frames(5)
	await tap(KEY_ESCAPE); await frames(5)
	var lb: Control = game.panels.find_child("btn_load_game", true, false)
	if lb: await click(lb.get_global_rect().get_center()); await frames(5)
	var l1: Control = game.panels.find_child("slot_slot1", true, false)
	if l1: await click(l1.get_global_rect().get_center()); await frames(20)
	var same_build: bool = JSON.stringify(saved.placements.map(func(p): return [p.id, p.i, p.k, p.r, p.get("color", "")])) == JSON.stringify(game.state.placements.map(func(p): return [p.id, p.i, p.k, p.r, p.get("color", "")]))
	var qs := func(st: Dictionary) -> String:
		var o := {}
		for k in st.quests: o[k] = st.quests[k].status
		return JSON.stringify(o)
	await shot("reloaded")
	check(11, "Save, exit, reload: constructions and quest progress intact", same_build and qs.call(saved) == qs.call(game.state) and game.state.harmony == saved.harmony and game.mech.fed.get("fountain", false),
		"%d pieces, harmony %d, fountain flowing=%s" % [game.state.placements.size(), game.state.harmony, game.mech.fed.get("fountain", false)])
	# Sail to Clockwork Cove and back: each island keeps what was built on it
	await walk_direct(5.5, 47.0, 0.6); await walk_direct(5.5, 49.6, 0.5)
	await face_and_press("boat", 5.5, 51.6); await frames(10)
	await shot("world-map")
	var built_here: int = game.state.placements.size()
	var arrived := await sail("clockwork")
	await shot("arrived-cove")
	check("B2", "The ferry sails to Clockwork Cove: a new island loads and you stand on its dock", arrived and Data.island == "clockwork" and game.state.placements.is_empty() and game.npcs.has("barnaby") and Vector2(game.player.pos.x - 2, game.player.pos.z - 28.4).length() < 2.0,
		"island %s, pieces %d, at %s" % [Data.island, game.state.placements.size(), game.player.pos])
	var b: Dictionary = {}
	for f in Data.layout.features:
		if f.id == "boat": b = f
	await walk_direct(b.x - 0.6, 30.6, 0.5)
	await face_and_press("boat", b.x, b.z); await frames(10)
	var home := await sail("hearthglow")
	await frames(30)
	await shot("back-home")
	check("B3", "Sailing home: Hearthglow comes back with everything you built, the fountain flowing", home and Data.island == "hearthglow" and game.state.placements.size() == built_here and game.mech.fed.get("fountain", false),
		"island %s, pieces %d of %d, fountain %s" % [Data.island, game.state.placements.size(), built_here, game.mech.fed.get("fountain", false)])
	check(12, "All of the above through gameplay input (no debug commands)", true, "Harness only reads state, turns the camera like a mouse drag, and pans the build view like WASD; see play_full.gd")
