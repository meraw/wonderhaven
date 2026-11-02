extends "res://tests/autoplay_base.gd"
## G1 check: walking with real keys, camera drag and zoom, interaction prompt on a sign.

func play() -> void:
	var p0: Vector3 = game.player.pos
	await hold(KEY_W, 1.2)
	var p1: Vector3 = game.player.pos
	check(1, "W moves the player", p0.distance_to(p1) > 2.0, "moved %.1f" % p0.distance_to(p1))
	var yaw0: float = game.cam.yaw
	mouse_button(Vector2(600, 300), MOUSE_BUTTON_RIGHT, true)
	for i in 10: mouse_move(Vector2(600 + i * 15, 300), Vector2(15, 0)); await frames(1)
	mouse_button(Vector2(750, 300), MOUSE_BUTTON_RIGHT, false)
	check(2, "Right-drag turns the camera", absf(game.cam.yaw - yaw0) > 0.3, "yaw %.2f → %.2f" % [yaw0, game.cam.yaw])
	var d0: float = game.cam.dist
	for i in 3: await click(Vector2(600, 300), MOUSE_BUTTON_WHEEL_UP)
	check(3, "Wheel zooms", game.cam.dist < d0, "%.1f → %.1f" % [d0, game.cam.dist])
	game.player.teleport(-33, 6.4, 0.0)
	await frames(5)
	check(4, "Standing by a sign shows an interaction prompt", game.prompt_panel.visible and "Read sign" in game.prompt_label.text, game.prompt_label.text)
	await shot("core")
