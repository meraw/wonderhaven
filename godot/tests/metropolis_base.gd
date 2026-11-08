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

## Walks along the nav graph from the nav spot nearest the player. (Toriano keeps this simpler start to a walk:
## the shared one picks a spot you can reach in a straight line at your own height, which on number 14's balcony,
## above the courtyard, picks a courtyard spot and walks you into the railing.)
func walk_to(x: float, z: float, tol: float = 0.8) -> bool:
	var f: Dictionary = game.state.flags
	var p: Vector3 = game.player.pos
	var path := Schedule.find_path(Schedule.nearest_node(p.x, p.z, f), Schedule.nearest_node(x, z, f), f)
	var pts: Array = []
	for i in path.size():
		var a: Array = Data.layout.nav_nodes[path[i]]
		pts.append(Vector2(a[0], a[1]))
		if i + 1 < path.size(): pts.append_array(game.crossing_path(path[i], path[i + 1]))
	var here := Vector2(game.player.pos.x, game.player.pos.z)
	var start := 0
	for i in pts.size():
		if pts[i].distance_to(here) < pts[start].distance_to(here): start = i
	for i in range(start, pts.size()):
		await walk_direct(pts[i].x, pts[i].y, 1.2)
	return await walk_direct(x, z, tol)

func node(id: String) -> Vector2:
	var a: Array = Data.layout.nav_nodes[P + id]
	return Vector2(a[0], a[1])

## Walks along the nav graph to a named spot with real keys, then checks you got there.
func nav_path(from: String, to: String) -> Array:
	var prev := {from: ""}
	var queue: Array = [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == to: break
		for e in Data.layout.nav_edges:
			var nxt := ""
			if String(e[0]) == cur: nxt = String(e[1])
			elif String(e[1]) == cur: nxt = String(e[0])
			if nxt != "" and not prev.has(nxt):
				prev[nxt] = cur
				queue.append(nxt)
	if not prev.has(to): return []
	var out: Array = []
	var c := to
	while c != "":
		out.push_front(c)
		c = String(prev[c])
	return out

func go(id: String, label: String) -> bool:
	var to := node(id)
	var t0 := Time.get_ticks_msec()
	var storey := NpcAgent.node_storey(P + id)
	if storey != INF and storey > 2.0:
		note("%s: setting off from %s" % [id, game.player.pos])
		for attempt in 3:
			if game.player.pos.y < 2.0: await storey_to(true)
			if game.player.pos.y < 2.0:
				note("%s: not up the stair yet, at %s" % [id, game.player.pos])
				continue
			var path := nav_path(P + "terrace_w", P + id)
			var start := 0
			var best := INF
			for i in path.size():
				var q: Array = Data.layout.nav_nodes[path[i]]
				var dd := Vector2(float(q[0]) - game.player.pos.x, float(q[1]) - game.player.pos.z).length()
				if dd < best: best = dd; start = i
			var fell := false
			for i in range(start, path.size()):
				var a: Array = Data.layout.nav_nodes[path[i]]
				await walk_direct(float(a[0]), float(a[1]), 0.6)
				if game.player.pos.y < 2.0: fell = true; break
			if not fell: break
			note("%s: came off the balcony at %s" % [id, game.player.pos])
	var d := Vector2(game.player.pos.x, game.player.pos.z).distance_to(to)
	for attempt in 3:
		if d < 2.5: break
		await walk_to(to.x, to.y, 1.5)
		d = Vector2(game.player.pos.x, game.player.pos.z).distance_to(to)
		if d < 2.5: break
		var near: Array = game.npcs.values().filter(func(a): return Vector2(a.pos.x - game.player.pos.x, a.pos.z - game.player.pos.z).length() < 2.5).map(func(a): return "%s at %s" % [a.def.id, a.pos])
		note("%s: stopped %.1f m short at %s, next to %s; waiting a moment" % [id, d, game.player.pos, near])
		await wait(2.0)
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

## Number 14 has two storeys round its courtyard, joined by the stone stair: the courtyard and the street below, the
## balcony ring, the flats and the roof terrace above. Changes storey there when you need to be on the other one.
func storey_to(up: bool) -> void:
	var is_up: bool = game.player.pos.y > 2.0
	if is_up == up: return
	var top := node("terrace_w"); var foot := node("stair_foot")
	if is_up:
		await walk_to(top.x, top.y, 0.8); await walk_direct(foot.x, foot.y, 0.6)
	else:
		await walk_to(foot.x, foot.y, 0.8); await walk_direct(top.x, top.y, 0.6)

## Talks to a Toriano villager (accepting what they offer, paying what they ask), like a player who knows the city:
## a villager on the other storey of number 14 is reached by the stair, and one on their way somewhere (lunch over,
## back to the office) is met where they're going rather than chased.
func chat(npc: String, accept: bool = true) -> bool:
	var id := P + npc
	for attempt in 5:
		var a = game.npcs[id]
		var near_tenement: bool = Vector2(a.pos.x + 38.0, a.pos.z - 112.0).length() < 16.0 or Vector2(game.player.pos.x + 38.0, game.player.pos.z - 112.0).length() < 16.0
		if near_tenement and absf(a.pos.y - game.player.pos.y) >= 1.5:
			if a.pos.y > 1.0 and a.pos.y < 3.0: await wait(3.0); continue   # on the stair: let them get where they're going
			await storey_to(a.pos.y > 2.0); continue
		if not a.waypoints.is_empty() and Data.layout.nav_nodes.has(a.goal):
			var g: Array = Data.layout.nav_nodes[a.goal]
			if Vector2(a.pos.x - g[0], a.pos.z - g[1]).length() > 12.0:
				note("%s is walking to %s: meeting them there" % [npc, a.goal])
				await walk_to(g[0], g[1], 2.0)
				for n in 90:
					if game.npcs[id].waypoints.is_empty(): break
					await wait(1.0)
				continue
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[id]
		if await face_and_press("npc:" + id, a.pos.x, a.pos.z):
			if await converse(id, accept): return true
			await frames(10)   # no conversation opened (a catch's panel still closing had the keys): try again
	note("could not reach %s to talk" % npc)
	return false

## The conversation once it's started: through the lines, accepting offers and paying when asked, then goodbye.
func converse(id: String, accept: bool) -> bool:
	for n in 20:
		if game.mode == "dialogue": break
		await frames(2)
	if game.mode != "dialogue": note("no dialogue with %s" % id); return false
	note("talking to %s" % id)
	for n in 300:
		await frames(4)
		if game.mode != "dialogue": return true
		var ui: DialogueUI = game.dialogue
		if not ui.choices.is_empty():
			var idx := -1
			if accept:
				for i in ui.choices.size():
					if str(ui.choices[i].label).begins_with("✨") or ui.choices[i].kind == "pay": idx = i; break
			if idx < 0:
				for i in ui.choices.size():
					if ui.choices[i].kind == "bye": idx = i
			await tap(game.dialogue.key_for(idx))
		else: await tap(KEY_E)
	return true

## The harness tops up materials a player would gather again and again (noted, so the report says so).
func top_up(items: Dictionary, why: String) -> void:
	var have := {}
	for k in items:
		var need := int(items[k]) - inv(k)
		if need > 0: game.state.inventory[k] = inv(k) + need; have[k] = need
	if not have.is_empty():
		note("harness top-up (%s): %s" % [why, have]); game.render_resources()

## Opens build mode on a zone (cycling through the unlocked sites, as the toolbar's arrows do).
func open_zone(zone_id: String, yaw: float = 0.35) -> bool:
	await tap(KEY_B); await frames(5)
	for i in 16:
		if game.build.current_zone.get("id", "") == P + zone_id: break
		game.build.cycle_zone(1); await frames(2)
	game.cam.yaw = yaw; game.cam.pitch = 1.05; game.cam.dist = 15
	await frames(6)
	return game.build.current_zone.get("id", "") == P + zone_id

## Places a piece at a cell with the mouse, at a height `y` (where the cursor lands: the floor or the top of what's
## there). Returns true when the piece is standing there afterwards.
func put(id: String, i: float, k: float, r: int = 0, y: float = 0.3) -> bool:
	await select_piece(id)
	for n in 12:   # (at a low frame rate a tap can go unnoticed: press until it's turned the right way)
		if game.build.rotation == r: break
		await tap(KEY_R); await frames(2)
	var fp := BuildGrid.footprint(Data.piece(id), r)
	# aim at the middle of the whole piece (a bed is two tiles long), or anywhere within half a tile of it, which picks
	# the same cell: a roof rests on a pillar's top, and between the pillars the cursor would fall through to the ground
	var aims: Array = [Vector3(i + fp.x / 2.0, y + 0.02, k + fp.y / 2.0)]
	for off in [Vector2(-0.4, -0.4), Vector2(0.4, 0.4), Vector2(-0.4, 0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0, -0.4), Vector2(0, 0.4)]:
		aims.append(aims[0] + Vector3(off.x, 0, off.y))
	game.build.focus = Vector3(aims[0].x, y, aims[0].z)
	var p := Vector2.ZERO
	var on_it := false
	for attempt in 27:   # point at the cell, and make sure the build cursor is on it (the view may still be gliding there)
		if attempt > 0 and attempt % 9 == 0: await turn_view(PI / 2.0)   # something taller is in the way: look from another side
		await settle()
		p = game.camera.unproject_position(aims[attempt % aims.size()])
		mouse_move(p, Vector2(1, 0)); await frames(4)
		var c: Dictionary = game.build.check.get("pl", {})   # what a click would place now
		if not c.is_empty() and c.id == id and is_equal_approx(float(c.i), i) and is_equal_approx(float(c.k), k) and int(c.r) == r and (y <= 0.3 or absf(float(c.y) - y) < 0.25): on_it = true; break   # (above the ground, on the right layer too)
		await frames(10)
	if not on_it:   # (clicking anyway would put the piece wherever the cursor happens to be)
		note("could not point at %d,%d (y %.1f) for %s: the cursor is on %s" % [i, k, y, id, game.build.check.get("pl", {})])
		return false
	var status_text: String = game.build.status_label.text if game.build.status_label else ""
	var before: int = game.state.placements.size()
	mouse_button(p, MOUSE_BUTTON_LEFT, true); mouse_button(p, MOUSE_BUTTON_LEFT, false)   # a quick click, on the cell just checked
	await frames(3)
	var ok: bool = game.state.placements.size() > before and game.state.placements.back().id == id and is_equal_approx(float(game.state.placements.back().i), i) and is_equal_approx(float(game.state.placements.back().k), k)
	if not ok: note("could not place %s at %d,%d (y %.1f): %s" % [id, i, k, y, status_text])
	return ok

## Turns the build view round by dragging with the right mouse button, as a player does to see past something.
func turn_view(angle: float) -> void:
	var mid: Vector2 = game.get_viewport().get_visible_rect().size / 2.0
	var px := angle / (0.0055 * float(game.settings.sensitivity))
	var steps := maxi(1, int(ceil(absf(px) / 20.0)))
	mouse_button(mid, MOUSE_BUTTON_RIGHT, true); await frames(1)
	for s in steps:
		mouse_move(mid, Vector2(px / steps, 0)); await frames(1)
	mouse_button(mid, MOUSE_BUTTON_RIGHT, false); await frames(2)

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

## A nap on a bench until the next wake-up time on offer (dawn, morning, noon, evening, night) at least `hours` away.
func nap_at_least(bench: String, hours: float) -> bool:
	var best := -1; var best_d := 99.0
	for w in [6, 9, 12, 18, 21]:
		var d := fposmod(float(w) - hour(), 24.0)
		if d >= hours and d < best_d: best_d = d; best = w
	return await sleep_until(bench, best)

## Takes the tram to a stop from whichever stop is nearest, as a player would.
func tram(to: String) -> bool:
	var p: Vector3 = game.player.pos
	var best := ""; var bd := INF
	for f in Data.layout.features.filter(func(x): return x.kind == "stop"):
		var d := Vector2(f.x - p.x, f.z - p.z).length()
		if d < bd: bd = d; best = String(f.id).trim_prefix(P)
	if best == to: return true
	return await ride(best, to, true)
