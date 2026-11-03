extends "res://tests/autoplay_base.gd"
## Screenshots of every menu panel (for reviewing the UI look); always passes unless a panel fails to open.

func play() -> void:
	game.state.tutorial.on = false; game.hud.apply_reveals()
	game.give({"wood": 12, "stone": 6, "flowers": 4, "fragment": 2}, null, true)
	game.state.quests["tool"] = {"status": "done", "progress": {}}
	game.state.quests["bridge"] = {"status": "active", "progress": {}}
	game.hud.render_tracker()
	await frames(20)
	await shot("hud")
	for p in [["inventory", KEY_I], ["journal", KEY_J], ["map", KEY_M], ["progress", KEY_P]]:
		await tap(p[1]); await frames(20)
		check(p[0], "%s panel opens" % p[0], game.mode == "menu", game.mode)
		await shot(p[0])
		await tap(KEY_ESCAPE); await frames(10)
	await tap(KEY_ESCAPE); await frames(20); await shot("pause"); await tap(KEY_ESCAPE); await frames(10)
	game.screens.title(); await frames(30); await shot("title")
	game.screens.creator(); await frames(30); await shot("creator")
