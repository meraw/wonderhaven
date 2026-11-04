extends "res://tests/full_base.gd"
## Full playthrough, part one: a new game through the guided first requests, the staged crossing and Elio's
## shop, with real key and mouse input. Checks acceptance tests 1-7, 9 and 10, then saves to slot 3 for
## play_full2.gd (the fountain, the bus turnaround, travel, saving and loading).
## Run: TIMEOUT=6000 ./play.sh res://tests/play_full.gd /tmp/out   (play.sh passes --title for both parts)

# ---- the playthrough ----------------------------------------------------------------------------
func play() -> void:
	# 1. New game + character creation
	await frames(20)
	await shot("title")
	var nb: Button = game.screens.find_child("btn_new", true, false)
	await click(nb.get_global_rect().get_center()); await frames(10)
	var le: LineEdit = game.screens.find_child("name_input", true, false)
	le.grab_focus(); le.select_all()
	for ch in "Pip": key(OS.find_keycode_from_string(ch), true); await frames(1); key(OS.find_keycode_from_string(ch), false)
	le.text = "Pip"; le.text_changed.emit("Pip")
	for opt in ["opt_hair_pigtails", "opt_hat_bow", "opt_eyeShape_sparkle", "opt_top_overalls"]:
		var b: Control = game.screens.find_child(opt, true, false)
		if b:
			(game.screens.find_child("creator_scroll", true, false) as ScrollContainer).ensure_control_visible(b)   # as scrolling would
			await frames(3)
			await click(b.get_global_rect().get_center()); await frames(4)
	await shot("creator")
	await click((game.screens.find_child("btn_start", true, false) as Control).get_global_rect().get_center())
	await frames(20)
	var card: Control = game.screens.find_child("btn_arrive", true, false)
	var saw_card: bool = card != null and game.mode == "cutscene"
	await shot("arrival-card")
	if card: await click(card.get_global_rect().get_center()); await frames(20)
	var a: Dictionary = game.state.appearance
	check(1, "Start a new game and create a character", saw_card and game.mode == "explore" and game.state.name == "Pip" and a.hair == "pigtails" and a.hat == "bow" and a.top != "overalls",
		"arrival card=%s name=%s hair=%s hat=%s locked overalls refused=%s" % [saw_card, game.state.name, a.hair, a.hat, a.top != "overalls"])
	await shot("arrival")
	# 2. Walk and camera
	var p0: Vector3 = game.player.pos
	var y0: float = game.cam.yaw
	await hold(KEY_W, 1.0)
	mouse_button(Vector2(600, 300), MOUSE_BUTTON_RIGHT, true)
	for i in 10: mouse_move(Vector2(600 + i * 15, 300), Vector2(15, 0)); await frames(1)
	mouse_button(Vector2(750, 300), MOUSE_BUTTON_RIGHT, false)
	var d0: float = game.cam.dist
	for i in 3: await click(Vector2(600, 300), MOUSE_BUTTON_WHEEL_UP)
	check(2, "Walk around and control the camera", game.player.pos.distance_to(p0) > 2.0 and absf(game.cam.yaw - y0) > 0.3 and game.cam.dist < d0,
		"moved %.1f, yaw Δ%.2f, zoom %.1f→%.1f" % [game.player.pos.distance_to(p0), game.cam.yaw - y0, d0, game.cam.dist])
	# 3. Talk to the Sindaco and accept
	await talk("percival")
	check(3, "Talk to an NPC, read dialogue and accept a quest", q("tool").get("status", "") == "active" and game.state.flags.get("hasTool", false), str(q("tool").get("status", "")))
	# 4. Gather
	await walk_to(-35.5, 6.0, 0.6)
	await gather_until("chop", func(): return int(q("tool").progress.get("wood", 0)) >= 3)
	check(4, "Collect resources and see the inventory update", inv("wood") >= 3 and inv("fragment") >= 1 and game.hud_res.find_child("res_wood", true, false) != null,
		"wood %d, lost things %d" % [inv("wood"), inv("fragment")])
	await talk("percival")
	print("   tool: ", q("tool").get("status", ""), " harmony ", game.state.harmony)
	# Bridge quest (Aldo, stuck at the bus stop): materials first (step 1 of 3)
	await talk("captain")
	await gather_until("chop", func(): return int(q("bridge").progress.get("wood", 0)) >= 10 and inv("wood") >= 16, [], 26)
	print("   materials: wood ", inv("wood"), " step ", game.story.engine.stage_index("bridge"))
	check("A1", "Staged request: the bridge's building step opens once the materials are gathered", game.story.engine.current_stage("bridge") == 1, "step %d of %d" % [game.story.engine.stage_index("bridge"), game.story.engine.stages("bridge").size()])
	await walk_to(0.5, -12.5, 1.0)
	await open_build("bridge")
	await shot("build-mode")
	await select_piece("bridgeDeck")
	for k in [-15, -16, -17]: await place_at(0, k)
	var warn := await place_at(0, -18)
	var refused: bool = not game.state.placements.any(func(p): return p.id == "bridgeDeck" and p.k == -18.0)
	await shot("invalid-warning")
	check(6, "Invalid placement is refused with a clear warning", refused and "post" in warn, warn)
	await select_piece("bridgePost"); await place_at(0, -18)
	await select_piece("bridgeDeck")
	for k in [-18, -19, -20, -22, -21]: await place_at(0, k, 0.2)
	await select_piece("railing"); await place_at(2, -15, 0.1, 0)
	var rail := {}
	for p in game.state.placements:
		if p.id == "railing": rail = p
	await tap(KEY_ESCAPE)
	await place_at(2, -15.4, 0.4)
	var sel: bool = not rail.is_empty() and game.build.selected == rail.uid
	await tap(KEY_R); await frames(3)
	var rot: int = int(rail.get("r", -1))
	await tap(KEY_N); await frames(3)
	await place_at(-2, -15)
	var moved: float = rail.get("i", 99.0)
	await tap(KEY_DELETE); await frames(3)
	var removed: bool = not game.state.placements.any(func(p): return p.id == "railing")
	key(KEY_CTRL, true); await tap(KEY_Z); key(KEY_CTRL, false); await frames(3)
	var undone: bool = game.state.placements.any(func(p): return p.id == "railing")
	key(KEY_CTRL, true); await tap(KEY_Y); key(KEY_CTRL, false); await frames(3)
	var redone: bool = not game.state.placements.any(func(p): return p.id == "railing")
	check(5, "Construction: place, rotate, move, remove (+ undo/redo)", sel and rot == 1 and moved == -2.0 and removed and undone and redone, "selected=%s r=%d moved=%s removed=%s undo=%s redo=%s" % [sel, rot, moved, removed, undone, redone])
	var step_rails: bool = game.story.engine.current_stage("bridge") == 2
	# last step: railings along both sides
	await select_piece("railing")
	for k in [-16, -17, -18, -19]: print("   railing: ", await place_at(0, k, 0.3, 1 if k % 2 == 0 else 3))
	check("A2", "Bridge built, then four railings finish the request", step_rails and game.story.engine.is_ready("bridge"), "rails step=%s ready=%s" % [step_rails, game.story.engine.is_ready("bridge")])
	await shot("bridge-built")
	await leave_build()
	# 7. Cross the bridge
	await walk_direct(0.5, -14.2, 0.6); await walk_direct(0.5, -24.0, 0.7)
	await shot("crossed-bridge")
	# On the far bank (z < -23; the river is -21..-15) and on dry ground, however far past the target the walk stopped.
	check(7, "A completed bridge can actually be crossed", game.player.pos.z < -23.0 and game.player.pos.y > -0.3, "z=%.1f y=%.2f" % [game.player.pos.z, game.player.pos.y])
	await walk_direct(0.5, -13.5, 0.7)
	var bp0: int = game.state.blueprints.size()
	var h0: int = game.state.harmony
	await talk("captain")
	check(9, "Completing a quest changes the world and grants rewards", q("bridge").get("status", "") == "done" and game.state.flags.get("orchardOpen", false) and game.state.harmony > h0, "harmony %d→%d, orchardOpen=%s" % [h0, game.state.harmony, game.state.flags.get("orchardOpen", false)])
	check(10, "New blueprints become available as you progress", game.state.blueprints.size() > bp0 and game.state.blueprints.has("flowerBed"), "%d→%d blueprints" % [bp0, game.state.blueprints.size()])
	# Workshop: materials, then Bram's plan, then furnishing
	await talk("bram")
	await gather_until("chop", func(): return int(q("workshop").progress.get("wood", 0)) >= 10 and inv("wood") >= 12, [], 18)
	await gather_until("mine", func(): return int(q("workshop").progress.get("metal", 0)) >= 2 and int(q("workshop").progress.get("crystal", 0)) >= 1, ["rock5", "rock0", "rock1", "rock2", "rock3", "rock4"], 14)
	print("   workshop materials: ", game.state.inventory, " step ", game.story.engine.stage_index("workshop"))
	await talk("bram")
	check("A3", "Talking to Bram is its own step: he explains the plan", game.story.engine.current_stage("workshop") == 2, "step %d" % game.story.engine.stage_index("workshop"))
	await walk_to(-7.0, 10.0, 1.0); await walk_direct(-11.0, 10.0, 0.8)
	await open_build("workshop")
	await shot("workshop-goals")
	await select_piece("workbench"); print("   workbench: ", await place_at(-15, 7, 0.1, 0))
	await select_piece("chair"); print("   chair: ", await place_at(-14, 9, 0.1, 2))
	for c in [[-13, 9], [-16, 9], [-15, 10], [-13, 11]]:   # wherever you're not standing
		if game.state.placements.filter(func(p): return p.id == "chair").size() >= 2: break
		print("   chair: ", await place_at(c[0], c[1], 0.1, 2))
	await select_piece("lamp"); print("   lamp: ", await place_at(-16, 11)); print("   lamp: ", await place_at(-11, 11))
	await select_piece("cabinet"); print("   cabinet: ", await place_at(-12, 7, 0.1, 0)); print("   cabinet: ", await place_at(-11, 7, 0.1, 0))
	await tap(KEY_ESCAPE)
	for p in game.state.placements:
		if p.id == "chair":
			await place_at(p.i, p.k, 0.5)
			await ui_click("sw_7bd389")
			break
	await shot("workshop-furnished")
	await leave_build()
	await walk_direct(-7.0, 10.0, 0.8)
	await talk("bram")
	print("   workshop: ", q("workshop").get("status", ""), " harmony ", game.state.harmony)
	check("A4", "The bigger workshop request is finished", q("workshop").get("status", "") == "done", str(q("workshop").get("status", "")))
	# Hand over to part two through a save, made in the pause menu
	check("A5", "Saved for part two (slot 3)", await save_to("slot3"), "")
