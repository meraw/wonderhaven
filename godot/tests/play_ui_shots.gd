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
		if p[0] == "map":
			var vm: Control = game.panels.find_child("village_map", true, false)
			var kinds := {}
			if vm != null:
				for e in vm.call("entries"): kinds[String(e.kind)] = int(kinds.get(String(e.kind), 0)) + 1
			var present: int = game.npcs.values().filter(func(a): return a.present).size()
			check("map-here", "M shows the village you're in: you, every villager about, the buildings and the bus stop", vm != null and kinds.get("you", 0) == 1 and kinds.get("villager", 0) == present and kinds.get("building", 0) >= 6 and kinds.get("bus", 0) >= 1, str(kinds))
		await shot(p[0])
		await tap(KEY_ESCAPE); await frames(10)
	await tap(KEY_ESCAPE); await frames(20); await shot("pause"); await tap(KEY_ESCAPE); await frames(10)
	game.screens.title(); await frames(30); await shot("title")
	game.screens.creator(); await frames(30); await shot("creator")
