extends "res://tests/autoplay_base.gd"
## Walk into buildings through their doors with real input; check you end up inside with the roof faded, and take
## a screenshot of each room. Villagers who live or work inside should be found indoors at the right hours.

func walk_in(bid: String, frames_max: int = 400) -> bool:
	var b: Dictionary = {}
	for x in Data.layout.buildings:
		if x.id == bid: b = x
	var di := Interiors.door_info(b)
	var outside: Vector2 = di.c + di.out * 2.2
	var inside: Vector2 = di.c - di.out * 1.6
	game.player.teleport(outside.x, outside.y, atan2(-di.out.x, -di.out.y)); game.cam.snap(); await frames(5)
	var room: AABB = Interiors.room(b, game.village.objects[bid].position.y)
	for n in frames_max:
		var p: Vector3 = game.player.pos
		var to := inside - Vector2(p.x, p.z)
		if to.length() < 0.4: break
		game.cam.yaw = lerp_angle(game.cam.yaw, atan2(-to.x, -to.y), 0.2)
		key(KEY_W, true); await frames(1)
	key(KEY_W, false); await frames(30)
	var p2: Vector3 = game.player.pos
	return room.has_point(Vector3(p2.x, room.position.y + 1.0, p2.z))

func play() -> void:
	game.state.tutorial.on = false; game.hud.apply_reveals()
	game.state.time.minute = 10 * 60.0
	await frames(10)
	for bid in ["bakery", "playerHouse", "odessaHouse", "fernHouse", "captainHut", "percivalHouse", "castle"]:
		var ok := await walk_in(bid)
		await frames(20)
		check("in-" + bid, "Walked in through the door of %s" % bid, ok and game.roof_fade.get(bid, 1.0) < 0.05, "pos %s roof %.2f" % [game.player.pos, game.roof_fade.get(bid, 1.0)])
		await shot("inside-" + bid)
	# Mabel works behind her counter mid-morning
	for i in 600:
		await frames(2)
		var m = game.npcs.mabel
		if Vector2(m.pos.x - (-11.8), m.pos.z - (-7.95)).length() < 1.2: break
	var mp: Vector3 = game.npcs.mabel.pos
	check("mabel", "Mabel is at work inside the bakery", Vector2(mp.x + 11.8, mp.z + 7.95).length() < 1.5, "at %s" % mp)
