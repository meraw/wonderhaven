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
			var d := cp.distance_to(game.cam.aim)
			if last_d >= 0.0:
				if (d - last_d) / dt > max_out: max_out = (d - last_d) / dt
				max_step = maxf(max_step, d - last_d)
				if last_d - d > 0.5: pull_ins += 1
			last_d = d
			for b in walls:
				if (b as AABB).has_point(cp) and not (b as AABB).has_point(game.cam.aim): inside += 1
			if cp.y < Heightfield.height(cp.x, cp.z) + 0.2: under += 1
		key(KEY_W, false)
		if i % 3 == 0:
			await shot("route-%d" % i)
			last_d = -1.0   # the screenshot takes a few frames: compare frame to frame again from the next one
	# A visible pop is a big jump between two frames; easing out at a few metres per second is the intended motion.
	check("c1", "No sudden outward jumps (largest move out in one frame %.2f m, fastest %.1f m/s, %d frames)" % [max_step, max_out, frames_n], max_step < 0.5, "")
	check("c2", "The camera never ends up inside a building", inside == 0, "%d frames inside" % inside)
	check("c3", "The camera never dips under the ground", under == 0, "%d frames under" % under)
	print("   pull-ins (moves closer of more than half a metre in one frame): ", pull_ins)
	await fixed_angles(walls)
	await tight_spots()
	await build_view()

func build_view() -> void:
	game.state.flags["hasTool"] = true
	game.cam.yaw = 0.3; game.cam.pitch = 0.6; game.cam.dist = 9.0
	game.player.teleport(4.0, 5.0, 0.0)
	await frames(2)
	game.cam.snap()
	await frames(5)
	await tap(KEY_B)
	await frames(30)
	var open: bool = game.build.active
	var size: Vector2 = get_viewport().get_visible_rect().size
	var cat: Control = game.build.catalog_panel if open else null
	var free_mid: float = (150.0 + cat.get_global_rect().position.y) / 2.0 if cat else size.y / 2.0
	var at: Vector2 = game.camera.unproject_position(game.cam.target)
	check("b1", "In build mode the middle of the view sits in the clear part of the screen, above the pieces (%.0f px from its middle)" % absf(at.y - free_mid), open and cat != null and absf(at.y - free_mid) < 25.0 and absf(at.x - size.x / 2.0) < 25.0, "")
	await shot("build-view")
	game.cam.dist = 6.0
	await frames(20)
	var before: Vector3 = game.build.focus
	await hold(KEY_D, 1.0)
	var close_step: float = Vector2(game.build.focus.x - before.x, game.build.focus.z - before.z).length()
	game.cam.dist = 30.0
	await frames(20)
	before = game.build.focus
	await hold(KEY_D, 1.0)
	var far_step: float = Vector2(game.build.focus.x - before.x, game.build.focus.z - before.z).length()
	check("b2", "The keys move the view gently close up and quickly far out (%.1f m and %.1f m in a second)" % [close_step, far_step], close_step > 1.5 and close_step < 6.0 and far_step > close_step * 3.0, "")
	game.cam.pitch = 0.45; game.cam.dist = 8.0
	await frames(10)
	await tap(KEY_ESCAPE)
	await frames(10)
	if game.build.active:
		await tap(KEY_ESCAPE)
		await frames(10)
	var walking_back: bool = not game.build.active and absf(game.cam.pitch - 0.6) < 0.01 and absf(game.cam.dist - 9.0) < 0.01
	await tap(KEY_B)
	await frames(10)
	check("b3", "Leaving build mode gives back the walking view, and build mode comes back as you left it", walking_back and game.build.active and absf(game.cam.pitch - 0.45) < 0.01 and absf(game.cam.dist - 8.0) < 0.01, "pitch %.2f dist %.1f" % [game.cam.pitch, game.cam.dist])
	await shot("build-view-low")
	await tap(KEY_ESCAPE)
	await frames(10)
	if game.build.active: await tap(KEY_ESCAPE)

const LANES := [Vector2(4, 5), Vector2(6.1, -3), Vector2(6.1, -13.3), Vector2(14.3, -13.3), Vector2(14.3, -5), Vector2(18.5, -3), Vector2(18.5, 17.8), Vector2(10.5, 17.9), Vector2(3, 17.5), Vector2(4, 23), Vector2(4, 33), Vector2(-5, 33), Vector2(-5, 21.5), Vector2(-16.5, 21.8), Vector2(-19.5, 21.5), Vector2(-19.5, 13), Vector2(-33, 13.3), Vector2(-33, 4.4), Vector2(-22, 4.4), Vector2(-16, -2), Vector2(-6, -2.2), Vector2(-0.1, -3.5), Vector2(-0.1, -12), Vector2(-0.1, -3.5), Vector2(-3, 3), Vector2(-3, 12.7), Vector2(2.9, 12.7), Vector2(2.9, 7.5), Vector2(4, 5)]
const MOVE_KEYS := [KEY_W, KEY_S, KEY_A, KEY_D]

func steer(to: Vector2) -> void:
	var y: float = game.cam.move_yaw()
	var ahead := to.dot(Vector2(-sin(y), -cos(y)))
	var side := to.dot(Vector2(cos(y), -sin(y)))
	var l := maxf(0.001, Vector2(ahead, side).length())
	key(KEY_W, ahead / l > 0.38); key(KEY_S, ahead / l < -0.38)
	key(KEY_D, side / l > 0.38); key(KEY_A, side / l < -0.38)

func fixed_angles(walls: Array) -> void:
	var total := 0; var hidden := 0; var close := 0; var inside := 0; var reached := 0; var legs := 0
	for turn in 4:
		game.cam.yaw = 0.3 + PI * 0.5 * turn; game.cam.pitch = 0.5; game.cam.dist = 8.5
		game.player.teleport(LANES[0].x, LANES[0].y, 0.0)
		await frames(2)
		game.cam.snap()
		await frames(5)
		for i in range(1, LANES.size()):
			var goal: Vector2 = LANES[i]
			legs += 1
			var best := INF
			var stalled := 0
			for n in 260:
				var p: Vector3 = game.player.pos
				var to := goal - Vector2(p.x, p.z)
				if to.length() < 0.9: reached += 1; break
				if to.length() < best - 0.05: best = to.length(); stalled = 0
				else: stalled += 1
				if stalled > 40: break
				steer(to)
				await frames(1)
				total += 1
				var cp: Vector3 = game.camera.global_position
				var d := cp.distance_to(game.cam.aim)
				if not game.player_char.visible: hidden += 1
				if d < 3.0: close += 1
				for b in walls:
					if (b as AABB).has_point(cp) and not (b as AABB).has_point(game.cam.aim): inside += 1
			if game.player.pos.distance_to(Vector3(goal.x, game.player.pos.y, goal.y)) > 0.9:
				game.player.teleport(goal.x, goal.y, 0.0)
				await frames(1)
		for k in MOVE_KEYS: key(k, false)
		await shot("lanes-%d" % turn)
	var n := maxf(1.0, float(total))
	check("c4", "Walking the lanes without turning the camera, you stay in view (hidden %.1f%% of %d frames)" % [100.0 * hidden / n, total], hidden / n < 0.02, "")
	check("c5", "and the camera keeps its distance (closer than 3 m %.1f%% of the time)" % (100.0 * close / n), close / n < 0.1, "")
	check("c6", "and stays outside the houses", inside == 0, "%d frames inside" % inside)
	print("   lane legs walked to the end: %d of %d" % [reached, legs])

const SPOTS := [[-0.1, -8.0, 1.87], [-0.8, -4.5, 5.01], [18.5, 13.0, 5.01], [4.0, 28.0, 1.87], [-3.0, 12.7, 0.3], [6.1, -8.0, 5.01]]

func tight_spots() -> void:
	var worst := INF
	var seen := true
	for i in SPOTS.size():
		var s: Array = SPOTS[i]
		game.cam.yaw = s[2]; game.cam.pitch = 0.5; game.cam.dist = 8.5
		game.player.teleport(s[0], s[1], 0.0)
		await frames(2)
		game.cam.snap()
		await frames(25)
		worst = minf(worst, game.camera.global_position.distance_to(game.cam.aim))
		seen = seen and game.player_char.visible
		await shot("tight-%d" % i)
	check("c7", "Standing by a house with the camera on its far side, the view looks over it (closest %.1f m)" % worst, seen and worst > 4.0, "")
