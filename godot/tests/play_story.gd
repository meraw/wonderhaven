extends "res://tests/autoplay_base.gd"
## G3 check: talk to the Sindaco, accept the welcome request, chop wood in the minigame, pick up a lost thing, turn in.

func talk_through(accept: bool = true) -> void:
	for n in 160:
		await frames(4)
		if game.mode != "dialogue": return
		var ui: DialogueUI = game.dialogue
		if not ui.choices.is_empty():
			var idx := -1
			for i in ui.choices.size():
				if accept and str(ui.choices[i].label).begins_with("✨"): idx = i; break
			if idx < 0:
				for i in ui.choices.size():
					if ui.choices[i].kind == "bye": idx = i
			print("   choose: ", ui.choices[idx].label)
			await tap(KEY_1 + idx)
		else:
			await tap(KEY_E)

func approach(x: float, z: float, face_x: float, face_z: float) -> void:
	game.player.teleport(x, z, atan2(face_x - x, face_z - z)); await frames(3)

func play() -> void:
	var od = game.npcs.percival
	await approach(od.pos.x - 1.4, od.pos.z, od.pos.x, od.pos.z)
	check("s0", "The Sindaco shows a request marker", od.marker_offer.visible, "")
	await tap(KEY_E); await frames(5)
	check(3, "E starts a conversation", game.mode == "dialogue", game.mode)
	await frames(30)
	await shot("dialogue")
	await talk_through()
	check("s1", "Accepted the welcome request and got the Geometra's kit", game.state.quests.get("tool", {}).get("status", "") == "active" and game.state.flags.get("hasTool", false), str(game.state.quests))
	# Chop a tree with the minigame
	var tree: Dictionary = Data.node_def("tree0")
	for attempt in 4:
		var n: Dictionary = Data.node_def("tree%d" % attempt)
		await approach(n.x, n.z + 1.4, n.x, n.z)
		await tap(KEY_E); await frames(5)
		if game.mode != "minigame": continue
		if attempt == 0:
			await frames(20)
			await shot("minigame")
			# the minigame sits in a panel at the side; the camera keeps you and the tree in view
			var vs: Vector2 = game.get_viewport().get_visible_rect().size
			var panel: Control = game.minigame.find_child("minigame_panel", true, false)
			var r: Rect2 = panel.get_global_rect() if panel else Rect2()
			var head: Vector2 = game.camera.unproject_position(game.player_char.head_world_pos())
			var on_screen: bool = Rect2(Vector2.ZERO, vs).has_point(head) and not r.has_point(head) and not game.camera.is_position_behind(game.player_char.head_world_pos())
			check("m1", "The minigame is a small panel at the side, not over the middle", panel != null and r.position.x > vs.x * 0.6 and r.get_area() < vs.x * vs.y * 0.15, "panel %s" % r)
			check("m2", "You can watch your character chop while you play", game.cam.mode == "action" and on_screen, "camera %s, head at %s" % [game.cam.mode, head])
		for k in 300:
			await frames(1)
			var mg = game.minigame.active.get("mg")
			if mg == null: break
			if not mg.done and mg.pause <= 0.0 and absf(mg.needle() - mg.center) < mg.width / 2.5: await tap(KEY_E)
		await frames(10)
		if game.state.quests.tool.progress.get("wood", 0) >= 3: break
	check(4, "Chopping gives wood and the HUD updates", int(game.state.inventory.get("wood", 0)) >= 3 and game.hud_res.find_child("res_wood", true, false) != null, "wood %s" % game.state.inventory.get("wood", 0))
	var f: Dictionary = Data.node_def("frag0")
	game.player.teleport(f.x - 2, f.z, PI / 2); game.cam.yaw = -PI / 2; game.cam.snap(); await frames(2)
	await hold(KEY_W, 0.8)
	check("s2", "Walking over a lost thing picks it up", int(game.state.inventory.get("fragment", 0)) >= 1, "fragments %s" % game.state.inventory.get("fragment", 0))
	await frames(10)
	od = game.npcs.percival
	check("s3", "The Sindaco now shows a ready marker", game.story.marker_for("percival") == "ready", game.story.marker_for("percival"))
	await approach(od.pos.x - 1.3, od.pos.z, od.pos.x, od.pos.z)
	await tap(KEY_E); await frames(5)
	await talk_through(false)
	check(9, "Turning in completes the request and raises the approval rating", game.state.quests.tool.status == "done" and game.state.harmony >= 10, "harmony %d" % game.state.harmony)
	await shot("after-quest")
