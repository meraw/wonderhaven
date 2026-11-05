extends "res://tests/autoplay_base.gd"
## Shared helpers for the full playthrough (play_full.gd, then play_full2.gd): walking along the nav graph, talking,
## gathering through the minigames, and building with real key and mouse input. The harness reads game state and
## turns the camera the way a mouse drag would; everything else is player input.

var errors_at_start := 0

# ---- helpers ------------------------------------------------------------------------------------
func steer(x: float, z: float) -> void:
	var p: Vector3 = game.player.pos
	game.cam.yaw = atan2(-(x - p.x), -(z - p.z)); game.cam.cur.yaw = game.cam.yaw

## Budgets count frames (as if at 30 fps), not wall-clock time: on a slow machine (software rendering, several
## runs at once) a wall-clock limit cut walks short while the game itself was fine.
func walk_direct(x: float, z: float, tol: float = 0.8, max_s: float = 40.0) -> bool:
	var budget := int(max_s * 30.0)
	var used := 0
	var last: Vector3 = game.player.pos
	var still := 0
	key(KEY_SHIFT, true)
	while used < budget:
		var p: Vector3 = game.player.pos
		if Vector2(x - p.x, z - p.z).length() < tol: break
		steer(x, z)
		key(KEY_W, true)
		await frames(2); used += 2
		if p.distance_to(last) > 0.1: last = p; still = 0
		else:
			still += 2
			if still > 36:   # no headway for about a second of frames: sidestep and hop, as a player would
				key(KEY_W, false); key(KEY_D if randf() < 0.5 else KEY_A, true); await frames(8); key(KEY_A, false); key(KEY_D, false)
				await tap(KEY_SPACE); still = 0; used += 8
	key(KEY_W, false); key(KEY_SHIFT, false)
	await frames(2)
	return Vector2(x - game.player.pos.x, z - game.player.pos.z).length() < tol + 0.4

func walk_to(x: float, z: float, tol: float = 0.8) -> bool:
	var f: Dictionary = game.state.flags
	var p: Vector3 = game.player.pos
	var path := Schedule.find_path(Schedule.nearest_node(p.x, p.z, f), Schedule.nearest_node(x, z, f), f)
	var pts: Array = []
	for i in path.size():
		var a: Array = Data.layout.nav_nodes[path[i]]
		pts.append(Vector2(a[0], a[1]))
		if i + 1 < path.size(): pts.append_array(game.crossing_path(path[i], path[i + 1]))
	# Follow the waypoints in order from the one nearest the player. (Skipping every waypoint farther from the goal
	# used to cut straight through buildings, e.g. into the workshop's back wall.)
	var here := Vector2(game.player.pos.x, game.player.pos.z)
	var start := 0
	for i in pts.size():
		if pts[i].distance_to(here) < pts[start].distance_to(here): start = i
	for i in range(start, pts.size()):
		await walk_direct(pts[i].x, pts[i].y, 1.2)
	return await walk_direct(x, z, tol)

func face_and_press(target_id: String, x: float, z: float) -> bool:
	for n in 8:
		if game.target != null and game.target.id == target_id:
			await tap(KEY_E); return true
		if target_id.begins_with("npc:"):   # villagers walk their routines: aim at where they are now
			var a = game.npcs[target_id.trim_prefix("npc:")]
			x = a.pos.x; z = a.pos.z
		var p: Vector3 = game.player.pos
		game.player.yaw = atan2(x - p.x, z - p.z); game.player.sync()
		steer(x, z); key(KEY_W, true); await frames(3); key(KEY_W, false); await frames(4)
	print("   could not target ", target_id, " (target: ", game.target.id if game.target else "none", ")")
	note("could not target %s (target: %s, at %s)" % [target_id, game.target.id if game.target else "none", game.player.pos])
	return false

func talk(id: String, accept: bool = true) -> bool:
	for attempt in 6:
		var a = game.npcs[id]
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[id]
		if await face_and_press("npc:" + id, a.pos.x, a.pos.z): break
	for n in 20:
		if game.mode == "dialogue": break
		await frames(2)
	if game.mode != "dialogue": print("   no dialogue with ", id); note("no dialogue with %s" % id); return false
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
			print("   ", id, " › ", ui.choices[idx].label)
			await tap(KEY_1 + idx)
		else: await tap(KEY_E)
	return true

## Plays a gathering minigame like a careful player: the key press lands on the next frame, so it aims at where the
## needle (or ring) will be then, using how far it moved since the last frame.
func play_minigame() -> void:
	var prev := -1.0
	for n in 2000:
		await frames(1)
		var a: Dictionary = game.minigame.active
		if a.is_empty(): return
		var mg = a.mg
		if mg.done: prev = -1.0; continue
		match a.kind:
			"chop":
				var nd: float = mg.needle()
				var pred: float = nd + (nd - prev if prev >= 0.0 else 0.0)
				prev = nd
				if mg.pause <= 0.0 and absf(pred - mg.center) < mg.width / 3.0: await tap(KEY_E); prev = -1.0
			"mine":
				var r: float = mg.r
				var pr: float = r + (r - prev if prev >= 0.0 else 0.0)
				prev = r
				if mg.pause <= 0.0 and pr < mg.target[1] - 0.015 and pr > mg.target[0] + 0.015: await tap(KEY_E); prev = -1.0
			"fish":
				if mg.phase == "bite": await tap(KEY_E)
				elif mg.phase == "reel": key(KEY_E, mg.tension < 0.5)
	key(KEY_E, false)

func gather_node(id: String) -> bool:
	var n := Data.node_def(id)
	var p: Vector3 = game.player.pos
	var d := maxf(0.01, Vector2(p.x - n.x, p.z - n.z).length())
	var ax: float = n.x if n.kind == "fish" else n.x + (p.x - n.x) / d * 1.4
	var az: float = n.z if n.kind == "fish" else n.z + (p.z - n.z) / d * 1.4
	await walk_to(ax, az, 0.6)
	if not await face_and_press(id, n.x, n.z): return false
	await frames(6)
	if game.mode == "minigame": await play_minigame()
	await frames(20)
	return true

func gather_until(kind: String, test: Callable, only: Array = [], rounds: int = 30) -> bool:
	var unreachable := {}   # a node we couldn't get to is skipped after that, rather than tried every round
	for r in rounds:
		if test.call(): return true
		var p: Vector3 = game.player.pos
		var ready: Array = Data.layout.nodes.filter(func(n): return n.kind == kind and (only.is_empty() or only.has(n.id)) and game.actions.ready(n) and not unreachable.has(n.id))
		ready.sort_custom(func(a, b): return Vector2(a.x - p.x, a.z - p.z).length() < Vector2(b.x - p.x, b.z - p.z).length())
		if ready.is_empty(): print("   waiting for ", kind, " to regrow"); note("waiting for %s to regrow" % kind); await wait(15.0); continue
		note("gather %s (round %d) wood=%d metal=%d stone=%d crystal=%d" % [ready[0].id, r, inv("wood"), inv("metal"), inv("stone"), inv("crystal")])
		if not await gather_node(ready[0].id): unreachable[ready[0].id] = true
	return test.call()

func settle() -> void:
	var last := Vector3.INF
	for n in 120:
		var c: Vector3 = game.camera.global_position
		if c.distance_to(last) < 0.002: return
		last = c; await frames(1)

func ui_click(name: String) -> bool:
	await frames(3)   # let containers finish laying out after a UI rebuild
	var n: Control = game.build.ui.find_child(name, true, false) if game.build.ui else null
	if n == null: print("   no UI node ", name); return false
	await click(n.get_global_rect().get_center()); return true

func open_build(zone_id: String) -> void:
	await tap(KEY_B); await frames(5)
	for i in 6:
		if game.build.current_zone.get("id", "") == zone_id: break
		game.build.cycle_zone(1); await frames(2)
	game.cam.yaw = 0.35; game.cam.pitch = 1.05; game.cam.dist = 15
	await frames(6)

func select_piece(id: String) -> void:
	var cat: String = Data.piece(id).cat
	await ui_click("tab_" + cat)
	if game.build.item_id != id: await ui_click("piece_" + id)

func place_at(i: float, k: float, y: float = 0.1, r: int = -1) -> String:
	if r >= 0:
		for n in 4:
			if game.build.rotation == r: break
			await tap(KEY_R)
	game.build.focus = Vector3(i + 0.5, 0, k + 0.5)
	await settle()
	var p: Vector2 = game.camera.unproject_position(Vector3(i + 0.5, y, k + 0.5))
	mouse_move(p); await frames(4)
	var status: String = game.build.status_label.text if game.build.status_label else ""
	await click(p); await frames(3)
	return status

func leave_build() -> void:
	for n in 3:
		if game.mode != "build": return
		await tap(KEY_ESCAPE); await frames(3)

func q(id: String) -> Dictionary:
	var r: Dictionary = game.state.quests.get(id, {})
	if not r.has("progress"): r = {"status": "", "progress": {}}
	return r
func inv(id: String) -> int: return int(game.state.inventory.get(id, 0))

## Saves into a slot through the pause menu, like a player would.
func save_to(slot: String) -> bool:
	await tap(KEY_ESCAPE); await frames(5)
	var before := float(SaveSystem.meta(slot).get("saved_at", 0.0))
	# (clicking rebuilds the panel and frees the buttons, so note what was found first)
	var sb: Control = game.panels.find_child("btn_save_game", true, false)
	var found_menu := sb != null
	if sb: await click(sb.get_global_rect().get_center()); await frames(5)
	var s1: Control = game.panels.find_child("slot_" + slot, true, false)
	var found_slot := s1 != null
	if s1: await click(s1.get_global_rect().get_center()); await frames(5)
	game.panels.close(); await frames(3)
	return found_menu and found_slot and float(SaveSystem.meta(slot).get("saved_at", 0.0)) > before

func feature(id: String) -> Dictionary:
	for f in Data.layout.features:
		if f.id == id: return f
	return {}

## Opens the sleep panel (walk up to it first) at a bed or bench and picks a wake-up time with a click.
func sleep_at(id: String, hour: int) -> bool:
	var f := feature(id)
	if not await face_and_press(id, f.x, f.z): return false
	await frames(6)
	var b := game.panels.find_child("wake_%d" % hour, true, false) as Button
	if b == null: note("no wake button in panel '%s'" % game.panels.current); return false
	await click(b.get_global_rect().get_center())
	for n in 200:
		await frames(2)
		if game.mode == "explore": break
	await frames(10)
	return true

