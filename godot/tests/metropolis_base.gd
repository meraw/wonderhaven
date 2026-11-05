extends "res://tests/full_base.gd"
## Helpers for Toriano's playthroughs (play_metropolis*.gd): walking to the city's nav spots, riding the tram with
## real input, talking to its villagers, building at a site's own height (an upstairs flat, the cathedral's roof),
## and reading its requests and its meter, the column inches in La Sera di Toriano.

const P := "metropolis_"

## The software renderer in a cloud session is slow in a city this size (its shadow pass and pixel fill, not the
## scripts): draw the 3D scene at half resolution and without the sun's shadows while playing (the interface stays
## sharp), and at full quality for screenshots.
func lighten() -> void:
	get_viewport().scaling_3d_scale = 0.5
	if game.sun: game.sun.shadow_enabled = false

func shot(name: String) -> void:
	get_viewport().scaling_3d_scale = 1.0
	if game.sun: game.sun.shadow_enabled = true
	await frames(3)
	await super.shot(name)
	lighten()

func node(id: String) -> Vector2:
	var a: Array = Data.layout.nav_nodes[P + id]
	return Vector2(a[0], a[1])

## Walks along the nav graph to a named spot with real keys, then checks you got there.
func go(id: String, label: String) -> bool:
	var to := node(id)
	var t0 := Time.get_ticks_msec()
	await walk_to(to.x, to.y, 1.5)
	var d := Vector2(game.player.pos.x, game.player.pos.z).distance_to(to)
	check(id, label, d < 2.5, "%.1f m away after %.0f s" % [d, (Time.get_ticks_msec() - t0) / 1000.0])
	return d < 2.5

## Holds a key towards (x, z) for a while and reports where you ended up.
func push_towards(x: float, z: float, seconds: float) -> Vector3:
	steer(x, z)
	key(KEY_SHIFT, true); key(KEY_W, true)
	await wait(seconds)
	key(KEY_W, false); key(KEY_SHIFT, false)
	await frames(4)
	return game.player.pos

## Takes the tram with real input: walk to the stop, press E, click the destination, and wait to step off there.
func ride(from: String, to: String, quiet: bool = false) -> bool:
	var a := feature(P + from); var b := feature(P + to)
	await walk_to(a.x + 1.0, a.z + (1.2 if a.z < 0 else -1.2), 0.8)
	var t0: float = game.state.time.minute + 1440.0 * float(game.state.time.day)
	if not await face_and_press(a.id, a.x, a.z): return false
	await frames(8)
	var btn := game.panels.find_child("ride_" + b.id, true, false) as Button
	if btn == null: note("no ride button for %s in panel '%s'" % [to, game.panels.current]); return false
	await click(btn.get_global_rect().get_center())
	for n in 300:
		await frames(2)
		if game.mode == "explore" and Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0: break
	var t1: float = game.state.time.minute + 1440.0 * float(game.state.time.day)
	var there := Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0
	if not quiet: check("ride_" + to, "the tram from %s to %s" % [a.name, b.name], there and t1 - t0 >= 2.0, "%.0f min later, %.1f m from the stop" % [t1 - t0, Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z))])
	elif not there: note("tram to %s: ended %.1f m away" % [to, Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z))])
	await frames(10)
	return there

## True when the player stands inside a building's walls.
func inside(bid: String) -> bool:
	for b in Data.layout.buildings:
		if b.id == P + bid: return absf(game.player.pos.x - b.x) < b.w / 2.0 and absf(game.player.pos.z - b.z) < b.d / 2.0
	return false

func who(id: String) -> String: return P + id
func status(qid: String) -> String: return String(game.state.quests.get(P + qid, {}).get("status", ""))
func done(qid: String) -> bool: return status(qid) == "done"
func inches() -> int: return LocationMeter.points(game.state, "metropolis")
func step_done(qid: String, oid: String) -> bool: return game.state.quests.get(P + qid, {}).get("done", {}).has(oid)

## Talks to a Toriano villager (accepting what they offer, paying what they ask) and reports the request's state.
func chat(npc: String, accept: bool = true) -> bool:
	return await talk(P + npc, accept)

## The harness tops up materials a player would gather again and again (noted, so the report says so).
func top_up(items: Dictionary, why: String) -> void:
	var have := {}
	for k in items:
		var need := int(items[k]) - inv(k)
		if need > 0: game.state.inventory[k] = inv(k) + need; have[k] = need
	if not have.is_empty():
		note("harness top-up (%s): %s" % [why, have]); game.render_resources()

## Opens build mode on a zone (cycling through the unlocked sites, as the toolbar's arrows do).
func open_zone(zone_id: String) -> bool:
	await tap(KEY_B); await frames(5)
	for i in 16:
		if game.build.current_zone.get("id", "") == P + zone_id: break
		game.build.cycle_zone(1); await frames(2)
	game.cam.yaw = 0.35; game.cam.pitch = 1.05; game.cam.dist = 15
	await frames(6)
	return game.build.current_zone.get("id", "") == P + zone_id

## Places a piece at a cell with the mouse, at a height `y` (where the cursor lands: the floor or the top of what's
## there). Returns true when the piece is standing there afterwards.
func put(id: String, i: float, k: float, r: int = 0, y: float = 0.3) -> bool:
	await select_piece(id)
	for n in 4:
		if game.build.rotation == r: break
		await tap(KEY_R)
	game.build.focus = Vector3(i + 0.5, y, k + 0.5)
	await settle()
	var p: Vector2 = game.camera.unproject_position(Vector3(i + 0.5, y + 0.02, k + 0.5))
	mouse_move(p); await frames(4)
	var status_text: String = game.build.status_label.text if game.build.status_label else ""
	var before: int = game.state.placements.size()
	await click(p); await frames(3)
	var ok: bool = game.state.placements.size() > before and game.state.placements.back().id == id and is_equal_approx(float(game.state.placements.back().i), i) and is_equal_approx(float(game.state.placements.back().k), k)
	if not ok: note("could not place %s at %d,%d (y %.1f): %s" % [id, i, k, y, status_text])
	return ok

## Places a list of [id, i, k, r, y]; returns how many went down.
func put_all(list: Array) -> int:
	var n := 0
	for e in list:
		if await put(e[0], e[1], e[2], e[3] if e.size() > 3 else 0, e[4] if e.size() > 4 else 0.3): n += 1
	return n

## Waits (sleeping on a bench, or just letting time pass if there's none near) until an hour of the day.
func sleep_until(bench: String, hour: int) -> bool:
	var f := feature(P + bench)
	await walk_to(f.x + 1.2, f.z + 0.6, 0.6)
	return await sleep_at(P + bench, hour)

func hour() -> float: return float(game.state.time.minute) / 60.0
