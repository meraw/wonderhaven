extends "res://tests/autoplay_base.gd"
## G2 check: build a bridge with real clicks, see warnings, rotate/move/remove/undo/redo, then walk across.

func ui_click(name: String) -> bool:
	var n: Control = game.build.ui.find_child(name, true, false)
	if n == null: print("   no UI node ", name); return false
	await click(n.get_global_rect().get_center())
	return true

func cell_click(i: float, k: float, y: float = 0.1) -> String:
	# Pan the build view onto the cell (as WASD panning would) so the catalog never covers it.
	game.build.focus = Vector3(i + 0.5, 0.0, k + 0.5)
	await settle()
	var p: Vector2 = game.camera.unproject_position(Vector3(i + 0.5, y, k + 0.5))
	mouse_move(p); await frames(4)
	var status: String = game.build.status_label.text if game.build.status_label else ""
	await click(p)
	await frames(3)
	return status

func settle() -> void:
	var last := Vector3.INF
	for n in 120:
		var c: Vector3 = game.camera.global_position
		if c.distance_to(last) < 0.002: return
		last = c; await frames(1)

func count(id: String, k = null) -> int:
	return game.state.placements.filter(func(p): return p.id == id and (k == null or p.k == k)).size()

func play() -> void:
	# Test setup: the bridge quest has been accepted (quests come in G3).
	game.state.flags["hasTool"] = true
	game.state.quests["bridge"] = {"status": "active", "progress": {}}
	game.state.inventory.merge({"wood": 30, "spark": 30, "stone": 10}, true)
	for b in ["bridgeDeck", "bridgePost", "railing"]: game.state.blueprints.append(b)
	game.render_resources()
	game.player.teleport(0.5, -12.5, PI)
	await frames(5)
	await tap(KEY_B)
	await frames(5)
	check("b1", "B opens build mode at the bridge site", game.mode == "build" and game.build.current_zone.get("id", "") == "bridge", game.build.current_zone.get("id", "none"))
	game.cam.yaw = 0.35; game.cam.pitch = 1.05; game.cam.dist = 15
	await ui_click("piece_bridgeDeck")
	for k in [-15, -16, -17]: await cell_click(0, k)
	var warn := await cell_click(0, -18)
	await shot("bridge-warning")
	check(6, "Invalid placement refused with a clear warning", count("bridgeDeck", -18.0) == 0 and "post" in warn, warn)
	await ui_click("piece_bridgePost")
	await cell_click(0, -18)
	await ui_click("piece_bridgeDeck")
	for k in [-18, -19, -20, -22, -21]: await cell_click(0, k, 0.2)
	print("   planks at k=", game.state.placements.filter(func(p): return p.id == "bridgeDeck").map(func(p): return p.k))
	check("b2", "Bridge placed plank by plank", count("bridgeDeck") == 8 and count("bridgePost") == 1, "%d planks, %d posts" % [count("bridgeDeck"), count("bridgePost")])
	# Place, select, rotate, move, remove, undo, redo a railing
	await ui_click("piece_railing")
	await cell_click(2, -15)
	var rail := {}
	for p in game.state.placements:
		if p.id == "railing": rail = p
	await tap(KEY_ESCAPE)
	await cell_click(2, -15.4, 0.4)   # the railing stands on the cell's north edge
	var selected_ok: bool = not rail.is_empty() and game.build.selected == rail.uid
	await tap(KEY_R); await frames(3)
	var rotated: int = int(rail.get("r", -1))
	await tap(KEY_N); await frames(3)
	await cell_click(-2, -15)
	var moved_to: float = rail.get("i", 99.0)
	await tap(KEY_DELETE); await frames(3)
	var removed := count("railing") == 0
	key(KEY_CTRL, true); await tap(KEY_Z); key(KEY_CTRL, false); await frames(3)
	var undone := count("railing") == 1
	key(KEY_CTRL, true); await tap(KEY_Y); key(KEY_CTRL, false); await frames(3)
	var redone := count("railing") == 0
	check(5, "Place, select, rotate, move, remove, undo and redo", selected_ok and rotated == 1 and moved_to == -2.0 and removed and undone and redone,
		"selected=%s r=%d moved_to=%s removed=%s undo=%s redo=%s" % [selected_ok, rotated, moved_to, removed, undone, redone])
	await shot("bridge-built")
	for n in 3:
		if game.mode != "build": break
		await tap(KEY_ESCAPE); await frames(3)
	check("b3", "Esc leaves build mode", game.mode == "explore", game.mode)
	# Walk across with W
	game.player.teleport(0.5, -13.5, PI)
	game.cam.yaw = 0.0
	await frames(3)
	key(KEY_W, true)
	for n in 120:
		await frames(2)
		if game.player.pos.z < -23.0: break
	key(KEY_W, false)
	check(7, "The built bridge can actually be crossed", game.player.pos.z < -23.0 and game.player.pos.y > -0.3, "z=%.1f y=%.2f" % [game.player.pos.z, game.player.pos.y])
	await shot("crossed")
