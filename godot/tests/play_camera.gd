extends "res://tests/autoplay_base.gd"
## Camera stability in play: walk a route past houses, through the square and along a hill while turning the
## camera, recording every frame. Checks there are no sudden jumps outward and that the view never ends up inside
## a building or under the ground.

const ROUTE := [Vector2(4, 5), Vector2(8, -4), Vector2(13, -6), Vector2(14, -12), Vector2(6, -13), Vector2(-4, -4), Vector2(-9, 2), Vector2(-4, 13), Vector2(9, 15), Vector2(12, 9)]

func play() -> void:
	game.state.tutorial.on = false; game.hud.apply_reveals()
	game.player.teleport(ROUTE[0].x, ROUTE[0].y, 0.0); game.cam.snap(); await frames(10)
	var max_step := 0.0; var max_out := 0.0; var pull_ins := 0; var inside := 0; var under := 0; var frames_n := 0
	var walls: Array = []   # the buildings' actual walls and roofs (the camera blockers add a margin around them)
	for b in Data.layout.buildings:
		for r in WorldStatics.footprint(b):   # a church is two boxes: the nave, and the tower at its back corner
			var top: float = 6.5 if b.kind == "castle" else (2.6 if b.kind == "caravan" else float(r.top))
			walls.append(AABB(Vector3(r.minX, 0.0, r.minZ), Vector3(r.maxX - r.minX, top, r.maxZ - r.minZ)))
	var last_d := -1.0
	for i in range(1, ROUTE.size()):
		var goal: Vector2 = ROUTE[i]
		for n in 400:
			var p: Vector3 = game.player.pos
			var to := goal - Vector2(p.x, p.z)
			if to.length() < 0.8: break
			# steer like a player: the camera turns gradually toward the walking direction
			var want := atan2(-to.x, -to.y)
			game.cam.yaw = lerp_angle(game.cam.yaw, want, 0.08)
			key(KEY_W, true)
			await frames(1)
			var dt := minf(0.1, maxf(0.001, get_process_delta_time()))   # the frame's game time, as the game caps it
			frames_n += 1
			var cp: Vector3 = game.camera.global_position
			var d := cp.distance_to(game.cam.target)
			if last_d >= 0.0:
				if (d - last_d) / dt > max_out: max_out = (d - last_d) / dt
				max_step = maxf(max_step, d - last_d)
				if last_d - d > 0.5: pull_ins += 1
			last_d = d
			for b in walls:
				if (b as AABB).has_point(cp) and not (b as AABB).has_point(game.cam.target): inside += 1
			if cp.y < Heightfield.height(cp.x, cp.z) + 0.2: under += 1
		key(KEY_W, false)
		if i % 3 == 0:
			await shot("route-%d" % i)
			last_d = -1.0   # the screenshot takes a few frames: compare frame to frame again from the next one
	# A visible pop is a big jump between two frames; easing out at a few metres per second is the intended motion.
	check("c1", "No sudden outward jumps (largest move out in one frame %.2f m, fastest %.1f m/s, %d frames)" % [max_step, max_out, frames_n], max_step < 0.5, "")
	check("c2", "The camera never ends up inside a building", inside == 0, "%d frames inside" % inside)
	check("c3", "The camera never dips under the ground", under == 0, "%d frames under" % under)
	print("   pull-ins (instant moves closer, by design when something comes between): ", pull_ins)
