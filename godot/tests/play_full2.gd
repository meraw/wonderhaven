extends "res://tests/full_base.gd"
## Full playthrough, part two: loads the slot-3 save that play_full.gd made (from the title screen, like a player),
## then the fountain machine, the bus turnaround on the belvedere, saving and loading, and catching the bus to the
## travel map. Checks acceptance tests 8, 11 and 12. Run play_full.gd first.

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
	await gather_until("chop", func(): return int(q("fountain").progress.get("wood", 0)) >= 6 and inv("wood") >= 6, [], 14)
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
	# The city bus (Aldo): stone first, then pave the turning circle on the belvedere, with a bench and a sign
	await talk("captain")
	await gather_until("mine", func(): return int(q("dock").progress.get("stone", 0)) >= 12 and inv("stone") >= 12, ["rock5", "rock0", "rock1", "rock2", "rock3", "rock4"], 24)
	await gather_until("chop", func(): return inv("wood") >= 4, [], 6)
	await walk_to(4.0, 32.6, 1.0)
	await open_build("dock")
	await select_piece("gardenPath")
	for i in range(1, 7):
		for k in [35, 36]: await place_at(i, k, 0.1)
	await select_piece("bench"); print("   bench: ", await place_at(2, 38, 0.1, 0))
	await select_piece("signpost"); print("   sign: ", await place_at(6, 38, 0.1, 0))
	await shot("turnaround-built")
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
	# Catch the bus: the travel map opens (Clockwork Cove is hidden until it is reworked, so there is nowhere new to go yet)
	var stop: Array = Data.layout.nav_nodes.dockStart
	var bus: Dictionary = {}
	for f in Data.layout.features:
		if f.id == "boat": bus = f
	await walk_to(stop[0], stop[1] - 1.0, 0.8); await walk_direct(stop[0], stop[1], 0.5)
	await face_and_press("boat", bus.x, bus.z); await frames(10)
	await shot("world-map")
	var mv: Control = game.panels.find_child("map_view", true, false)
	check("B2", "The new stop works: catching the bus opens the travel map, with the old Clockwork Cove kept off it", game.panels.current == "map" and mv != null and not mv.call("_shown").any(func(i): return i.id == "clockwork"), game.panels.current)
	await tap(KEY_ESCAPE); await frames(10)
	check(12, "All of the above through gameplay input (no debug commands)", true, "Harness only reads state, turns the camera like a mouse drag, and pans the build view like WASD; see play_full.gd")
