extends "res://tests/autoplay_base.gd"
## Dialogue layout: with the most choices in the game, every option is fully on screen, and Esc says goodbye.

func open_choices(id: String) -> void:
	var a = game.npcs[id]
	game.player.teleport(a.pos.x - 1.3, a.pos.z, PI / 2); await frames(3)
	await tap(KEY_E)
	for n in 60:
		await frames(4)
		if not game.dialogue.choices.is_empty(): return
		if game.mode == "dialogue": await tap(KEY_E)

func play() -> void:
	game.state.quests["tool"] = {"status": "done", "progress": {}}
	game.state.quests["bridge"] = {"status": "done", "progress": {}}
	game.state.quests["workshop"] = {"status": "active", "progress": {}}
	game.state.flags["orchardOpen"] = true; game.state.flags["hasTool"] = true; game.state.flags["toolGiven"] = true
	game.state.tutorial.on = false; game.hud.apply_reveals()   # this test sets up mid-game state directly
	for id in ["odessa", "mabel", "percival"]:
		await open_choices(id)
		await frames(10)
		var vs: Vector2 = game.get_viewport().get_visible_rect().size
		var all_on := true
		var n: int = game.dialogue.choice_box.get_child_count()
		for b in game.dialogue.choice_box.get_children():
			var r: Rect2 = (b as Control).get_global_rect()
			if r.position.y < 0 or r.end.y > vs.y or r.position.x < 0 or r.end.x > vs.x: all_on = false
		await shot("choices-" + id)
		check("d-" + id, "%s: all %d choices fully on screen" % [id, n], n > 0 and all_on, "esc hint: " + game.dialogue.esc_label.text)
		await tap(KEY_ESCAPE)
		for k in 30:
			await frames(4)
			if game.mode != "dialogue": break
			await tap(KEY_ESCAPE if not game.dialogue.choices.is_empty() else KEY_E)
		check("e-" + id, "Esc leaves the conversation with %s" % id, game.mode == "explore", game.mode)
		await frames(20)
