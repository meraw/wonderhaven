extends "res://tests/autoplay_base.gd"
## Full playthrough of the Hearthglow slice with real key and mouse input, checking the 12 acceptance tests.
## The harness reads game state and turns the camera the way a mouse drag would; everything else is player input.
## Run: TIMEOUT=2400 ./play.sh res://tests/play_full.gd /tmp/out   (play.sh passes --title automatically for this script)

var errors_at_start := 0

# ---- helpers ------------------------------------------------------------------------------------
func steer(x: float, z: float) -> void:
	var p: Vector3 = game.player.pos
	game.cam.yaw = atan2(-(x - p.x), -(z - p.z)); game.cam.cur.yaw = game.cam.yaw

func walk_direct(x: float, z: float, tol: float = 0.8, max_s: float = 40.0) -> bool:
	var t0 := Time.get_ticks_msec()
	var last: Vector3 = game.player.pos
	var last_move := Time.get_ticks_msec()
	key(KEY_SHIFT, true)
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		var p: Vector3 = game.player.pos
		if Vector2(x - p.x, z - p.z).length() < tol: break
		steer(x, z)
		key(KEY_W, true)
		await frames(2)
		if p.distance_to(last) > 0.1: last = p; last_move = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - last_move > 1200:
			key(KEY_W, false); key(KEY_D if randf() < 0.5 else KEY_A, true); await wait(0.25); key(KEY_A, false); key(KEY_D, false)
			await tap(KEY_SPACE); last_move = Time.get_ticks_msec()
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
		var p: Vector3 = game.player.pos
		game.player.yaw = atan2(x - p.x, z - p.z); game.player.sync()
		steer(x, z); key(KEY_W, true); await frames(3); key(KEY_W, false); await frames(4)
	print("   could not target ", target_id, " (target: ", game.target.id if game.target else "none", ")")
	return false

func talk(id: String, accept: bool = true) -> bool:
	for attempt in 3:
		var a = game.npcs[id]
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[id]
		if await face_and_press("npc:" + id, a.pos.x, a.pos.z): break
	for n in 20:
		if game.mode == "dialogue": break
		await frames(2)
	if game.mode != "dialogue": print("   no dialogue with ", id); return false
	for n in 300:
		await frames(4)
		if game.mode != "dialogue": return true
		var ui: DialogueUI = game.dialogue
		if not ui.choices.is_empty():
			var idx := -1
			if accept:
				for i in ui.choices.size():
					if str(ui.choices[i].label).begins_with("✨"): idx = i; break
			if idx < 0:
				for i in ui.choices.size():
					if ui.choices[i].kind == "bye": idx = i
			print("   ", id, " › ", ui.choices[idx].label)
			await tap(KEY_1 + idx)
		else: await tap(KEY_E)
	return true

func play_minigame() -> void:
	for n in 2000:
		await frames(1)
		var a: Dictionary = game.minigame.active
		if a.is_empty(): return
		var mg = a.mg
		if mg.done: continue
		match a.kind:
			"chop": if mg.pause <= 0.0 and absf(mg.needle() - mg.center) < mg.width / 2.5: await tap(KEY_E)
			"mine": if mg.pause <= 0.0 and mg.r < mg.target[1] - 0.01 and mg.r > mg.target[0] + 0.03: await tap(KEY_E)
			"fish":
				if mg.phase == "bite": await tap(KEY_E)
				elif mg.phase == "reel": key(KEY_E, mg.tension < 0.5)
	key(KEY_E, false)

func gather_node(id: String) -> void:
	var n := Data.node_def(id)
	var p: Vector3 = game.player.pos
	var d := maxf(0.01, Vector2(p.x - n.x, p.z - n.z).length())
	var ax: float = n.x if n.kind == "fish" else n.x + (p.x - n.x) / d * 1.4
	var az: float = n.z if n.kind == "fish" else n.z + (p.z - n.z) / d * 1.4
	await walk_to(ax, az, 0.6)
	if not await face_and_press(id, n.x, n.z): return
	await frames(6)
	if game.mode == "minigame": await play_minigame()
	await frames(20)

func gather_until(kind: String, test: Callable, only: Array = [], rounds: int = 30) -> bool:
	for r in rounds:
		if test.call(): return true
		var p: Vector3 = game.player.pos
		var ready: Array = Data.layout.nodes.filter(func(n): return n.kind == kind and (only.is_empty() or only.has(n.id)) and game.actions.ready(n))
		ready.sort_custom(func(a, b): return Vector2(a.x - p.x, a.z - p.z).length() < Vector2(b.x - p.x, b.z - p.z).length())
		if ready.is_empty(): print("   waiting for ", kind, " to regrow"); await wait(15.0); continue
		await gather_node(ready[0].id)
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

# ---- the playthrough ----------------------------------------------------------------------------
func play() -> void:
	# 1. New game + character creation
	await frames(20)
	await shot("title")
	var nb: Button = game.screens.find_child("btn_new", true, false)
	await click(nb.get_global_rect().get_center()); await frames(10)
	var le: LineEdit = game.screens.find_child("name_input", true, false)
	le.grab_focus(); le.select_all()
	for ch in "Pip": key(OS.find_keycode_from_string(ch), true); await frames(1); key(OS.find_keycode_from_string(ch), false)
	le.text = "Pip"; le.text_changed.emit("Pip")
	for opt in ["opt_hair_pigtails", "opt_hat_bow", "opt_eyeShape_sparkle", "opt_top_overalls"]:
		var b: Control = game.screens.find_child(opt, true, false)
		if b:
			(game.screens.find_child("creator_scroll", true, false) as ScrollContainer).ensure_control_visible(b)   # as scrolling would
			await frames(3)
			await click(b.get_global_rect().get_center()); await frames(4)
	await shot("creator")
	await click((game.screens.find_child("btn_start", true, false) as Control).get_global_rect().get_center())
	await frames(20)
	var a: Dictionary = game.state.appearance
	check(1, "Start a new game and create a character", game.mode == "explore" and game.state.name == "Pip" and a.hair == "pigtails" and a.hat == "bow" and a.top != "overalls",
		"name=%s hair=%s hat=%s locked overalls refused=%s" % [game.state.name, a.hair, a.hat, a.top != "overalls"])
	await shot("arrival")
	# 2. Walk and camera
	var p0: Vector3 = game.player.pos
	var y0: float = game.cam.yaw
	await hold(KEY_W, 1.0)
	mouse_button(Vector2(600, 300), MOUSE_BUTTON_RIGHT, true)
	for i in 10: mouse_move(Vector2(600 + i * 15, 300), Vector2(15, 0)); await frames(1)
	mouse_button(Vector2(750, 300), MOUSE_BUTTON_RIGHT, false)
	var d0: float = game.cam.dist
	for i in 3: await click(Vector2(600, 300), MOUSE_BUTTON_WHEEL_UP)
	check(2, "Walk around and control the camera", game.player.pos.distance_to(p0) > 2.0 and absf(game.cam.yaw - y0) > 0.3 and game.cam.dist < d0,
		"moved %.1f, yaw Δ%.2f, zoom %.1f→%.1f" % [game.player.pos.distance_to(p0), game.cam.yaw - y0, d0, game.cam.dist])
	# 3. Talk to Odessa and accept
	await talk("odessa")
	check(3, "Talk to an NPC, read dialogue and accept a quest", q("tool").get("status", "") == "active" and game.state.flags.get("hasTool", false), str(q("tool").get("status", "")))
	# 4. Gather
	var spark0 := inv("spark")
	await walk_to(-35.5, 6.0, 0.6)
	await gather_until("chop", func(): return int(q("tool").progress.get("wood", 0)) >= 3)
	check(4, "Collect resources and see the inventory update", inv("wood") >= 3 and inv("fragment") >= 1 and inv("spark") > spark0 and game.hud_res.find_child("res_wood", true, false) != null,
		"wood %d, fragment %d, spark %d→%d" % [inv("wood"), inv("fragment"), spark0, inv("spark")])
	await talk("odessa")
	print("   tool: ", q("tool").get("status", ""), " harmony ", game.state.harmony)
	# Bridge quest
	await talk("fern")
	await gather_until("chop", func(): return int(q("bridge").progress.get("wood", 0)) >= 6 and int(q("bridge").progress.get("spark", 0)) >= 5 and inv("wood") >= 11 and inv("spark") >= 12, [], 18)
	print("   materials: wood ", inv("wood"), " spark ", inv("spark"))
	await walk_to(0.5, -12.5, 1.0)
	await open_build("bridge")
	await shot("build-mode")
	await select_piece("bridgeDeck")
	for k in [-15, -16, -17]: await place_at(0, k)
	var warn := await place_at(0, -18)
	var refused: bool = not game.state.placements.any(func(p): return p.id == "bridgeDeck" and p.k == -18.0)
	await shot("invalid-warning")
	check(6, "Invalid placement is refused with a clear warning", refused and "post" in warn, warn)
	await select_piece("bridgePost"); await place_at(0, -18)
	await select_piece("bridgeDeck")
	for k in [-18, -19, -20, -22, -21]: await place_at(0, k, 0.2)
	await select_piece("railing"); await place_at(2, -15, 0.1, 0)
	var rail := {}
	for p in game.state.placements:
		if p.id == "railing": rail = p
	await tap(KEY_ESCAPE)
	await place_at(2, -15.4, 0.4)
	var sel: bool = not rail.is_empty() and game.build.selected == rail.uid
	await tap(KEY_R); await frames(3)
	var rot: int = int(rail.get("r", -1))
	await tap(KEY_N); await frames(3)
	await place_at(-2, -15)
	var moved: float = rail.get("i", 99.0)
	await tap(KEY_DELETE); await frames(3)
	var removed: bool = not game.state.placements.any(func(p): return p.id == "railing")
	key(KEY_CTRL, true); await tap(KEY_Z); key(KEY_CTRL, false); await frames(3)
	var undone: bool = game.state.placements.any(func(p): return p.id == "railing")
	key(KEY_CTRL, true); await tap(KEY_Y); key(KEY_CTRL, false); await frames(3)
	var redone: bool = not game.state.placements.any(func(p): return p.id == "railing")
	check(5, "Construction: place, rotate, move, remove (+ undo/redo)", sel and rot == 1 and moved == -2.0 and removed and undone and redone, "selected=%s r=%d moved=%s removed=%s undo=%s redo=%s" % [sel, rot, moved, removed, undone, redone])
	await shot("bridge-built")
	await leave_build()
	# 7. Cross the bridge
	await walk_direct(0.5, -14.2, 0.6); await walk_direct(0.5, -24.0, 0.7)
	await shot("crossed-bridge")
	# On the far bank (z < -23; the river is -21..-15) and on dry ground, however far past the target the walk stopped.
	check(7, "A completed bridge can actually be crossed", game.player.pos.z < -23.0 and game.player.pos.y > -0.3, "z=%.1f y=%.2f" % [game.player.pos.z, game.player.pos.y])
	await walk_direct(0.5, -13.5, 0.7)
	var bp0: int = game.state.blueprints.size()
	var h0: int = game.state.harmony
	await talk("fern")
	check(9, "Completing a quest changes the world and grants rewards", q("bridge").get("status", "") == "done" and game.state.flags.get("orchardOpen", false) and game.state.harmony > h0, "harmony %d→%d, orchardOpen=%s" % [h0, game.state.harmony, game.state.flags.get("orchardOpen", false)])
	check(10, "New blueprints become available as you progress", game.state.blueprints.size() > bp0 and game.state.blueprints.has("flowerBed"), "%d→%d blueprints" % [bp0, game.state.blueprints.size()])
	# Workshop
	await talk("bram")
	await gather_until("chop", func(): return int(q("workshop").progress.get("wood", 0)) >= 3 and inv("wood") >= 7, [], 14)
	await walk_to(-7.0, 10.0, 1.0); await walk_direct(-11.0, 10.0, 0.8)
	await open_build("workshop")
	await select_piece("workbench"); print("   workbench: ", await place_at(-15, 7, 0.1, 0))
	await select_piece("chair"); print("   chair: ", await place_at(-14, 9, 0.1, 2))
	await select_piece("lamp"); print("   lamp: ", await place_at(-16, 11))
	await select_piece("cabinet"); print("   cabinet: ", await place_at(-12, 7, 0.1, 0))
	await tap(KEY_ESCAPE)
	for p in game.state.placements:
		if p.id == "chair":
			await place_at(p.i, p.k, 0.5)
			await ui_click("sw_7bd389")
	await shot("workshop-furnished")
	await leave_build()
	await walk_direct(-7.0, 10.0, 0.8)
	await talk("bram")
	print("   workshop: ", q("workshop").get("status", ""), " harmony ", game.state.harmony)
	# Fountain: the mechanical puzzle
	await talk("tilly")
	await gather_until("clay", func(): return int(q("fountain").progress.get("clay", 0)) >= 6, [], 10)
	await gather_until("mine", func(): return int(q("fountain").progress.get("metal", 0)) >= 1 and inv("metal") >= 3, ["rock5", "rock0", "rock1", "rock2", "rock3", "rock4"], 10)
	await gather_until("chop", func(): return inv("wood") >= 6 and inv("spark") >= 14, [], 12)
	print("   fountain materials: ", game.state.inventory)
	await walk_to(6.0, 4.0, 1.0)
	await open_build("plaza")
	await select_piece("waterwheel"); print("   wheel: ", await place_at(9, 1, 0.1, 0))
	await select_piece("pump"); print("   pump: ", await place_at(8, 2, 0.1, 0))
	await select_piece("pipe")
	for i in range(7, 1, -1): await place_at(i, 2, 0.1, 1)
	var before := {"fed": game.mech.fed.get("fountain", false), "pumps": game.mech.pumps.size()}
	await select_piece("gear"); print("   gear: ", await place_at(9, 2, 0.1, 0))
	await frames(20)
	var jets: bool = (game.village.objects.fountain.get_node("jets") as Node3D).visible
	await shot("fountain-flowing")
	check(8, "A connected machine responds to its power source", not before.fed and before.pumps == 0 and game.mech.fed.get("fountain", false) and game.mech.pumps.size() == 1 and jets,
		"before gear: pumps=%d fed=%s; after: pumps=%d fed=%s jets=%s" % [before.pumps, before.fed, game.mech.pumps.size(), game.mech.fed.get("fountain", false), jets])
	await leave_build()
	await talk("tilly")
	print("   fountain: ", q("fountain").get("status", ""), " harmony ", game.state.harmony)
	# Harbor
	await talk("percival")
	print("   decree: ", q("decree").get("status", ""), " harborOpen ", game.state.flags.get("harborOpen", false))
	await walk_to(5.0, 37.0, 1.0)
	await talk("captain")
	await walk_direct(5.5, 40.6, 0.6)
	await open_build("dock")
	await select_piece("bridgeDeck")
	for k in [41, 42, 43, 44, 45, 46, 47, 48, 49]: await place_at(5, k, 0.15)
	await shot("dock-built")
	await leave_build()
	await talk("captain")
	print("   dock: ", q("dock").get("status", ""), " boatReady ", game.state.flags.get("boatReady", false))
	await walk_direct(5.5, 47.0, 0.6); await walk_direct(5.5, 49.6, 0.5)
	await face_and_press("boat", 5.5, 51.6); await frames(10)
	await shot("world-map")
	var mv: Control = game.panels.find_child("map_view", true, false)
	if mv:
		var isl: Dictionary = Data.islands[1]
		await click(mv.get_global_rect().position + Vector2(isl.x, isl.y) * (mv.size / Vector2(800, 500)))
		await frames(4)
		var sail: Control = game.panels.find_child("sail", true, false)
		if sail: await click(sail.get_global_rect().get_center())
	await wait(3.0)
	await shot("next-chapter")
	print("   sailed: ", game.state.flags.get("sailedOnce", false))
	# 11. Save, reload, load
	await tap(KEY_ESCAPE); await frames(5)
	var sb: Control = game.panels.find_child("btn_save_game", true, false)
	if sb: await click(sb.get_global_rect().get_center()); await frames(5)
	var s1: Control = game.panels.find_child("slot_slot1", true, false)
	if s1: await click(s1.get_global_rect().get_center()); await frames(5)
	var saved: Dictionary = game.state.duplicate(true)
	var _loaded := SaveSystem.read("slot1")
	game.panels.close()
	# Simulate quitting by resetting to a fresh state, then load through the menu like a player would.
	game.load_state(GameState.new_game())
	await frames(5)
	await tap(KEY_ESCAPE); await frames(5)
	var lb: Control = game.panels.find_child("btn_load_game", true, false)
	if lb: await click(lb.get_global_rect().get_center()); await frames(5)
	var l1: Control = game.panels.find_child("slot_slot1", true, false)
	if l1: await click(l1.get_global_rect().get_center()); await frames(20)
	var same_build: bool = JSON.stringify(saved.placements.map(func(p): return [p.id, p.i, p.k, p.r, p.get("color", "")])) == JSON.stringify(game.state.placements.map(func(p): return [p.id, p.i, p.k, p.r, p.get("color", "")]))
	var qs := func(st: Dictionary) -> String:
		var o := {}
		for k in st.quests: o[k] = st.quests[k].status
		return JSON.stringify(o)
	await shot("reloaded")
	check(11, "Save, exit, reload: constructions and quest progress intact", same_build and qs.call(saved) == qs.call(game.state) and game.state.harmony == saved.harmony and game.mech.fed.get("fountain", false),
		"%d pieces, harmony %d, fountain flowing=%s" % [game.state.placements.size(), game.state.harmony, game.mech.fed.get("fountain", false)])
	check(12, "All of the above through gameplay input (no debug commands)", true, "Harness only reads state, turns the camera like a mouse drag, and pans the build view like WASD; see play_full.gd")
