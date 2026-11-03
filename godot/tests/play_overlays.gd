extends "res://tests/autoplay_base.gd"
## Build mode during the guided day: the guide card, a tip card, the build checklist and the controls must not
## overlap. Then the workshop: from inside, with the roof faded, the room is visible (roof gone, camera inside).

func _overlaps(a: Control, b: Control) -> bool:
	return a.is_visible_in_tree() and b.is_visible_in_tree() and a.get_global_rect().grow(-2).intersects(b.get_global_rect().grow(-2))

func play() -> void:
	# Guided day at the bridge step, as a new player would meet it
	game.state.quests["tool"] = {"status": "done", "progress": {}}
	game.state.quests["bridge"] = {"status": "active", "progress": {}, "done": {}}
	game.state.flags["hasTool"] = true; game.state.flags["toolGiven"] = true
	game.state.tutorial.step = Tutorial.steps().map(func(x): return x.id).find("build")
	game.state.tutorial.seen.erase("build")
	game.hud.apply_reveals(); game.hud.render_guide()
	game.player.teleport(0.5, -13.0, PI); game.cam.snap(); await frames(10)
	await tap(KEY_B); await frames(30)
	check("o1", "Build mode opens at the bridge with the guide and the building tip", game.mode == "build" and game.hud.guide_card.visible and game.hud.tip_card.visible, "%s guide=%s tip=%s" % [game.mode, game.hud.guide_card.visible, game.hud.tip_card.visible])
	var panels: Array = [game.hud.guide_card, game.hud.tip_card]
	for c in game.build.ui.find_children("*", "PanelContainer", true, false): panels.append(c)
	var clashes: Array = []
	for i in panels.size():
		for j in range(i + 1, panels.size()):
			var a: Control = panels[i]; var b: Control = panels[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			if _overlaps(a, b): clashes.append("%s × %s" % [a.name, b.name])
	await shot("build-bridge-guided")
	check("o2", "No explanation boxes overlap in build mode", clashes.is_empty(), ", ".join(clashes))
	check("o3", "The request tracker steps aside while building", not game.hud.tracker.is_visible_in_tree(), "")
	await tap(KEY_ESCAPE); await frames(10)
	# Workshop from inside
	game.state.tutorial.on = false; game.hud.apply_reveals()
	game.state.quests["bridge"] = {"status": "done", "progress": {}}
	game.state.quests["workshop"] = {"status": "active", "progress": {}, "done": {}}
	game.player.teleport(-13.0, 10.0, PI / 2); game.cam.yaw = 1.2; game.cam.pitch = 0.45; game.cam.dist = 8.0; game.cam.snap()
	await frames(90)
	var cp: Vector3 = game.camera.global_position
	var room: AABB = Props.camera_rooms()[0]
	var inside_view := room.has_point(cp) or cp.y > room.end.y
	check("o4", "Standing in the workshop, the camera stays inside or looks in over the walls", inside_view, "camera at %s" % cp)
	check("o5", "The roof has faded right away", game.roof_alpha < 0.05, "alpha %.2f" % game.roof_alpha)
	await shot("workshop-inside")
	await tap(KEY_B); await frames(40)
	await shot("workshop-build")
	check("o6", "Furnishing the workshop: build mode opens on it with the roof gone", game.mode == "build" and game.build.current_zone.get("id", "") == "workshop" and game.roof_alpha < 0.05, "%s %s" % [game.build.current_zone.get("id", ""), game.roof_alpha])
