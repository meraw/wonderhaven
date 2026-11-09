extends "res://tests/full_base.gd"

const P := "cliffs_"
const ID := "cliffs"
const TREES := ["cliffs_pine0", "cliffs_pine1", "cliffs_pine2", "cliffs_pine3", "cliffs_pine4", "cliffs_pine5", "cliffs_chestnut0", "cliffs_chestnut1"]
const SECTIONS := ["welcome", "hut", "wall", "monorail", "cellar", "boats", "path", "herbs", "tables", "lunch", "swim", "shelter", "easter"]

func at(x: float, z: float, tol: float = 1.6) -> bool:
	return Vector2(game.player.pos.x - x, game.player.pos.z - z).length() < tol

func spot(id: String) -> Vector2:
	var a: Array = Data.layout.nav_nodes[id]
	return Vector2(a[0], a[1])

func go(id: String) -> bool:
	var p := spot(id)
	await walk_to(p.x, p.y, 0.6)
	if not at(p.x, p.y, 1.6) or absf(Heightfield.height(p.x, p.y) - game.player.pos.y) > 0.6:
		note("not at %s yet (at %s): walking round again" % [id, where()])
		await walk_to(p.x, p.y, 0.6)
	return at(p.x, p.y, 1.6)

func y_near(v: float, tol: float = 0.4) -> bool: return absf(game.player.pos.y - v) < tol

func building(id: String) -> Dictionary:
	return Data.layout.buildings.filter(func(b): return b.id == id)[0]

func inside(id: String) -> bool:
	var b := building(id)
	var o: Node3D = game.village.objects[id]
	var room := Interiors.room(b, o.position.y)
	return room.has_point(Vector3(game.player.pos.x, room.position.y + 1.0, game.player.pos.z))

func enter(id: String, name: String, roofed: bool = true) -> bool:
	var p := spot(id + ":spot")
	await walk_to(p.x, p.y, 0.7)
	await wait(1.0)
	await shot(name)
	return inside(id) and (not roofed or float(game.roof_fade.get(id, 1.0)) < 0.2)

func where() -> String: return "(%.1f, %.1f, %.1f)" % [game.player.pos.x, game.player.pos.y, game.player.pos.z]

func play() -> void:
	if not game.shot_cfg.has("from"): await arrive_as_if_played(["hearthglow", "river_town", "rice_village", "metropolis", "port"])
	var s: Dictionary = game.state
	s.tutorial = Tutorial.new_state(false, true)
	s.time.minute = 10 * 60.0
	game.hud.apply_reveals()
	await frames(10)
	if game.shot_cfg.get("part", "") == "shots": await shots(); return
	if game.shot_cfg.get("part", "") != "requests": await walk_around()
	if game.shot_cfg.get("part", "") != "map": await requests()

func view(x: float, z: float, yaw: float, pitch: float, dist: float, h: float, name: String) -> void:
	game.state.time.minute = h * 60.0
	game.player.teleport(x, z)
	game.cam.yaw = yaw; game.cam.pitch = pitch; game.cam.dist = dist
	game.cam.limits.explore = [2.0, 120.0, 0.05, 1.5]
	game.cam.update(0.016, game.player.pos); game.cam.snap()
	await wait(2.5)
	await shot(name)

func story_at(flags: Array) -> void:
	for f in flags: game.state.flags[f] = true
	game.request_rebuild()
	await await_rebuild()

func shots() -> void:
	game.shot_cfg["weather"] = "clear"
	await story_at(["cliffs_welcomed"])
	await view(0.0, 24.0, 0.35, 0.6, 20.0, 10.5, "harbour-square-in-the-morning")
	await view(0.0, 10.0, 0.25, 0.5, 14.0, 10.0, "boats-in-the-street")
	await story_at(["cliffs_boats_launched", "cliffs_monorailRuns", "cliffs_sanctuaryPath"])
	await view(0.0, 29.0, PI - 0.3, 0.6, 22.0, 10.5, "boats-launched")
	await view(0.0, 10.0, 0.25, 0.5, 14.0, 10.0, "the-street-opened-up")
	await view(19.0, -45.5, PI / 2.0, 0.75, 16.0, 12.0, "the-monorail-running")
	await view(0.0, 24.0, 0.35, 0.6, 22.0, 22.0, "serenza-at-night")
	await view(16.0, 46.5, -PI / 2.0 + 0.25, 0.12, 8.0, 22.0, "the-next-villages-at-night")
	game.shot_cfg["weather"] = "mist"
	await view(0.0, -45.0, PI, 0.5, 30.0, 6.5, "sea-fog-in-the-ravine")
	game.shot_cfg["weather"] = "clear"

func walk_around() -> void:
	var s: Dictionary = game.state
	var sp: Dictionary = Data.layout.spawn
	check("c1", "Arrived on Serenza's station platform", Data.island == ID and at(sp.x, sp.z, 2.5) and y_near(10.0), where())
	check("c2", "With Toriano's story played before it", s.quests.get("metropolis_angel", {}).get("status", "") == "done", "")
	await shot("arrival")
	var ok := await enter("cliffs_station", "waiting-room")
	check("r1", "Into the station's waiting room, its roof fading", ok, where())
	ok = await go("square")
	check("c3", "Down the station lane and the main street to the harbour square", ok and y_near(0.9), where())
	await shot("harbour-square")
	await gulls_fly_up()
	ok = await enter("cliffs_bar", "nunzias-bar")
	check("r2", "Into Nunzia's bar", ok, where())
	ok = await go("ferry")
	check("c4", "Out along the breakwater to the ferry landing", ok and y_near(1.1), where())
	ok = await go("beach")
	check("c5", "Onto the pebble beach", ok and game.player.pos.y > -0.3 and game.player.pos.y < 0.9, where())
	ok = await enter("cliffs_church", "church")
	check("r3", "Into the church on the rocks", ok, where())
	ok = await go("cellarSq")
	check("c6", "Under the railway arch and up the steps to the cellar square", ok and y_near(10.0), where())
	ok = await enter("cliffs_cellar", "cellar")
	check("r4", "Into the growers' cellar", ok, where())
	ok = await enter("cliffs_workshop", "workshop")
	check("r5", "Into Trenin's workshop", ok, where())
	ok = await go("top0")
	check("c7", "Up the stair through the terraces to the pines at the top", ok and y_near(27.0), where())
	await shot("top-of-the-terraces")
	animals_on_arrival()
	for wp in [Vector2(-15.0, -59.6), Vector2(-30.0, -59.6), Vector2(-44.0, -59.6), Vector2(-47.8, -59.4), Vector2(-48.6, -57.8)]:
		await walk_direct(wp.x, wp.y, 0.5, 30.0)
	ok = at(-48.6, -57.8, 1.0)
	check("c8", "Along the top to the sanctuary", ok and y_near(29.5), where())
	await shot("sanctuary")
	ok = await enter("cliffs_sanctuary", "chapel")
	check("r6", "Into the sanctuary chapel", ok, where())
	ok = await go("muleGullyS")
	var north := spot("muleGullyN")
	await walk_direct(north.x, north.y, 0.8, 12.0)
	check("c9", "The gully stops you on the mule path until it's bridged", ok and game.player.pos.y < 18.0, where())
	ok = await go("rail5")
	var up := spot("rail6")
	await walk_direct(up.x, up.y, 0.8, 12.0)
	check("c10", "The slip stops you on the monorail's path", ok and game.player.pos.y < 21.0, where())
	ok = await go("hut")
	check("r7", "To the roofless hut on E4", ok and y_near(18.0), where())
	await shot("the-hut")
	ok = await go("platform")
	check("c11", "Back to the platform", ok and y_near(10.0), where())
	s.time.minute = 8 * 60.0 + 8.0
	await wait(3.0)
	var trains: Node = game.village.get_node_or_null("cliffs_trains")
	var regional: Node3D = trains.models.regional if trains else null
	check("t1", "At 8:11 the morning regional stands at the platform", regional != null and regional.visible and absf(regional.position.x + 12.0) < 0.1, str(regional.position) if regional else "")
	await shot("the-8-10-regional")
	await night_and_fog()
	s.time.minute = 10 * 60.0
	await frames(10)

func animals() -> Node: return game.village.get_node_or_null("cliffs_animals")

func gulls_fly_up() -> void:
	var an := animals()
	if an == null:
		check("a1", "Gulls sit on the quay and fly up as you come close", false, "no animals")
		return
	var seat := Vector3(-7.0, 0.95, 30.85)
	var gull: Dictionary = {}
	for q in an.gulls:
		if not q.ring and (q.seat as Vector3).distance_to(seat) < 0.1: gull = q
	var sitting: bool = not gull.is_empty() and float(gull.flying) <= 0.0 and (gull.obj as Node3D).position.distance_to(seat) < 0.05
	await walk_direct(seat.x, seat.z - 1.0, 0.5, 15.0)
	await wait(1.2)
	var up: bool = not gull.is_empty() and float(gull.flying) > 0.0 and (gull.obj as Node3D).position.y > seat.y + 0.5
	check("a1", "A gull sits on the quay and flaps up as you come close", sitting and up, "sitting=%s up=%s %s" % [sitting, up, where()])
	await shot("gull-flies-up")

func animals_on_arrival() -> void:
	var an := animals()
	if an == null:
		check("a2", "Lizards bask on the tended terraces' walls", false, "no animals")
		return
	var shown: Array = an.lizards.filter(func(l): return (l.obj as Node3D).visible)
	var tended: bool = shown.all(func(l): return String(l.terrace) in ["w1", "e2"])
	check("a2", "By day lizards bask on the walls of W1 and E2, the only terraces still tended", shown.size() >= 2 and tended,
		"%d shown at %s" % [shown.size(), Clock.text(game.state.time)])
	var swallows: int = an.swallows.filter(func(sw): return (sw.obj as Node3D).visible).size()
	check("a3", "A few swallows over the village when you arrive", swallows == 4, "%d" % swallows)

func night_and_fog() -> void:
	var s: Dictionary = game.state
	s.time.minute = 22 * 60.0
	await wait(4.0)
	var lit: Array = game.village.lamps.filter(func(l): return (l.get_node("light") as OmniLight3D).visible)
	check("n1", "At night the lamp posts light the main street, the stairs, the square and the harbour", lit.size() >= 15 and game.village.lamp_glow > 0.8, "%d lit" % lit.size())
	var far: Array = game.village.window_mats.filter(func(m): return String(m.resource_name) == "far_coast_glass")
	check("n2", "And windows glow in the next villages along the coast", far.size() == 1 and float(far[0].emission_energy_multiplier) > 1.0, "%d" % far.size())
	await view(0.0, 24.0, 0.35, 0.6, 22.0, 22.0, "serenza-at-night")
	await view(16.0, 46.5, -PI / 2.0 + 0.25, 0.12, 8.0, 22.0, "the-next-villages-at-night")
	game.shot_cfg["weather"] = "mist"
	await view(0.0, -45.0, PI, 0.5, 30.0, 6.5, "sea-fog-in-the-ravine")
	var fog: MeshInstance3D = game.village.valley_fog
	var thick: float = float((fog.material_override as ShaderMaterial).get_shader_parameter("amount")) if fog else 0.0
	check("n3", "On a misty morning the sea fog fills the ravine up to the station", fog != null and fog.visible and thick > 0.6, "%.2f" % thick)
	game.shot_cfg.erase("weather")
	game.player.teleport(Data.layout.spawn.x, Data.layout.spawn.z)
	await frames(10)

func room_at(x: float, z: float) -> String:
	for b in Data.layout.buildings:
		if not b.has("interior") or not b.has("w"): continue
		if absf(x - float(b.x)) < float(b.w) / 2.0 and absf(z - float(b.z)) < float(b.d) / 2.0: return String(b.id)
	return ""

func level_node(x: float, z: float) -> String:
	var hy := Heightfield.height(x, z)
	var room := room_at(x, z)
	var best := ""
	var bd := INF
	for id in Data.layout.nav_nodes:
		var a: Array = Data.layout.nav_nodes[id]
		if String(id).contains(":"):
			if room == "" or not String(id).begins_with(room + ":"): continue
		elif room != "": continue
		elif absf(Heightfield.height(a[0], a[1]) - hy) > 0.6: continue
		var d := Vector2(float(a[0]) - x, float(a[1]) - z).length()
		if d < bd: bd = d; best = String(id)
	return best if best != "" else Schedule.nearest_node(x, z, game.state.flags)

func level_ok(x: float, z: float) -> bool: return absf(Heightfield.height(x, z) - game.player.pos.y) < 0.7

func start_node() -> String:
	var p: Vector3 = game.player.pos
	var here := Vector2(p.x, p.z)
	var room := room_at(p.x, p.z)
	var ids: Array = Data.layout.nav_nodes.keys()
	ids.sort_custom(func(a, b): return Vector2(Data.layout.nav_nodes[a][0], Data.layout.nav_nodes[a][1]).distance_to(here) < Vector2(Data.layout.nav_nodes[b][0], Data.layout.nav_nodes[b][1]).distance_to(here))
	for id in ids.slice(0, 14):
		var a: Array = Data.layout.nav_nodes[id]
		if String(id).contains(":") != (room != "") or (room != "" and not String(id).begins_with(room + ":")): continue
		if room == "" and not level_ok(a[0], a[1]): continue
		if line_clear(here, Vector2(a[0], a[1])): return String(id)
	for id in ids.slice(0, 14):
		var a: Array = Data.layout.nav_nodes[id]
		if room == "" and not String(id).contains(":") and level_ok(a[0], a[1]): return String(id)
	return Schedule.nearest_node(p.x, p.z, game.state.flags)

func leave_hut() -> void:
	var p: Vector3 = game.player.pos
	if p.x < 18.9 or p.x > 22.1 or p.z < -42.0 or p.z > -39.8 or absf(p.y - 18.0) > 0.6: return
	for pl in game.state.placements:
		if String(pl.id) == "doorWall" and int(pl.i) == 19 and int(pl.k) == -41 and not pl.get("state", {}).get("open", false):
			await walk_direct(19.5, -40.6, 0.3, 10.0)
			await face_and_press("pl:%d" % int(pl.uid), 19.5, -39.9)
			await frames(6)
	await walk_direct(19.5, -40.3, 0.3, 10.0)
	await walk_direct(19.5, -38.9, 0.4, 10.0)
	note("out of the hut through its door, at %s" % where())

func walk_to(x: float, z: float, tol: float = 0.8) -> bool:
	await leave_hut()
	var f: Dictionary = game.state.flags
	var p: Vector3 = game.player.pos
	var path := Schedule.find_path(start_node(), level_node(x, z), f)
	var pts: Array = []
	for i in path.size():
		var a: Array = Data.layout.nav_nodes[path[i]]
		pts.append(Vector2(a[0], a[1]))
		if i + 1 < path.size(): pts.append_array(game.crossing_path(path[i], path[i + 1]))
	var here := Vector2(game.player.pos.x, game.player.pos.z)
	var start := 0
	for i in pts.size():
		if pts[i].distance_to(here) < pts[start].distance_to(here) and level_ok(pts[i].x, pts[i].y) and line_clear(here, pts[i]): start = i
	for i in range(start, pts.size()):
		var at_p := Vector2(game.player.pos.x, game.player.pos.z)
		if i > start and not line_clear(at_p, pts[i]): await walk_direct(pts[i - 1].x, pts[i - 1].y, 0.35)
		await walk_direct(pts[i].x, pts[i].y, 1.2)
	return await walk_direct(x, z, tol)

func gather_node(id: String) -> bool:
	var n := Data.node_def(id)
	var ax: float = n.x
	var az: float = n.z
	if n.kind != "fish":
		var near := level_node(n.x, n.z)
		var a: Array = Data.layout.nav_nodes[near]
		var dv := Vector2(float(a[0]) - n.x, float(a[1]) - n.z)
		if dv.length() > 0.01: dv = dv.normalized() * 1.4
		else: dv = Vector2(0, 1.4)
		ax = n.x + dv.x
		az = n.z + dv.y
	await walk_to(ax, az, 0.6)
	if not await face_and_press(id, n.x, n.z): return false
	await frames(6)
	if game.mode == "minigame": await play_minigame()
	await frames(20)
	for k in 200:
		if game.mode != "cutscene": break
		await frames(2)
	return true

func _to_window(p: Vector2) -> Vector2: return get_viewport().get_final_transform() * p
func mouse_move(p: Vector2, rel: Vector2 = Vector2.ZERO) -> void: super.mouse_move(_to_window(p), rel)
func mouse_button(p: Vector2, button: int, pressed: bool) -> void: super.mouse_button(_to_window(p), button, pressed)

func qs(id: String) -> String: return String(game.state.quests.get(P + id, {}).get("status", ""))
func stage(id: String) -> int: return game.story.engine.current_stage(P + id)
func flag(f: String) -> bool: return game.state.flags.get(P + f, false)
func terrace(t: String) -> bool: return game.state.flags.get(P + "terrace_" + t, false)
func pts() -> int: return LocationMeter.points(game.state, ID)
func reading() -> String: return LocationMeter.reading(LocationMeter.def(ID), pts())
func hour() -> float: return float(game.state.time.minute) / 60.0

func step(qid: String, oid: String) -> Dictionary:
	for o in Data.quest(P + qid).objectives:
		if String(o.id) == oid: return o
	return {}

func must_met(qid: String, oid: String, n: int) -> bool:
	game.story.engine.invalidate()
	return game.story.engine.commission(P + qid, step(qid, oid)).musts[n].ok

func step_done(qid: String, oid: String) -> bool:
	game.story.engine.invalidate()
	return game.story.engine.objective(P + qid, step(qid, oid)).done

var _game_id := 0
func talk(id: String, accept: bool = true, want: String = "") -> bool:
	_game_id = game.get_instance_id()
	for attempt in 14:
		var a = game.npcs[id]
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[id]
		if Vector2(a.pos.x - game.player.pos.x, a.pos.z - game.player.pos.z).length() > 3.0 or absf(a.pos.y - game.player.pos.y) > 1.2: continue
		if not await face_and_press("npc:" + id, a.pos.x, a.pos.z): continue
		for n in 20:
			if game.mode == "dialogue": break
			await frames(2)
		if game.mode == "dialogue": break
		note("pressed E at %s, no dialogue yet (mode %s)" % [id, game.mode])
	if game.mode != "dialogue": note("no dialogue with %s" % id); return false
	note("talking to %s at %s" % [id, Clock.text(game.state.time)])
	for n in 300:
		await frames(4)
		if not is_instance_valid(game) or game.mode != "dialogue": return true
		var ui: DialogueUI = game.dialogue
		if not ui.choices.is_empty():
			var idx := -1
			if accept:
				for i in ui.choices.size():
					var c: Dictionary = ui.choices[i]
					var offer: bool = c.kind == "offer" or str(c.label).begins_with("✨")
					if c.kind == "pay" or c.kind == "yes" or (offer and want != "" and String(c.get("id", "")) == want): idx = i; break
			if idx < 0:
				for i in ui.choices.size():
					if ui.choices[i].kind == "bye": idx = i
			if idx < 0: idx = 0
			print("   ", id, " › ", ui.choices[idx].label)
			await tap(game.dialogue.key_for(idx))
		else: await tap(KEY_E)
	return true

func await_rebuild(max_s: float = 60.0) -> bool:
	var old_id: int = game.get_instance_id() if is_instance_valid(game) else _game_id
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		await frames(2)
		var cur = get_tree().current_scene
		if cur != null and cur.get_instance_id() != old_id and cur.get("started") == true:
			game = cur
			await frames(30)
			return true
	return false

func choose(id: String, want: String) -> bool:
	for attempt in 6:
		var a = game.npcs[P + id]
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[P + id]
		if await face_and_press("npc:" + P + id, a.pos.x, a.pos.z): break
	for n in 300:
		await frames(4)
		if game.mode != "dialogue": return false
		var ui: DialogueUI = game.dialogue
		if ui.choices.is_empty(): await tap(KEY_E); continue
		var kinds: Array = ui.choices.map(func(c): return c.kind)
		if kinds.has(want): await tap(game.dialogue.key_for(kinds.find(want))); return true
		var idx: int = kinds.find("yes") if kinds.has("yes") else (kinds.find("pay") if kinds.has("pay") else kinds.find("bye"))
		await tap(game.dialogue.key_for(idx))
	return false

func open_shop(id: String) -> bool:
	if not await choose(id, "shop"): note("no shop option at %s" % id); return false
	for k in 80:
		await frames(4)
		if game.panels.current == "shop": break
		if game.mode == "dialogue" and game.dialogue.choices.is_empty(): await tap(KEY_E)
	await frames(20)
	return game.panels.current == "shop"

func buy(id: String, item: String, n: int) -> bool:
	if n <= 0: return true
	if not await open_shop(id): return false
	var line := -1
	for e in Shop.stock(game.state, P + id):
		if e.get("kind", "") == "items" and e.items.has(item): line = e.i; break
	var ok := line >= 0
	var have := inv(item)
	for k in n:
		var b := game.panels.find_child("buy_%d" % line, true, false) as Button
		if b == null or b.disabled: ok = false; break
		await click(b.get_global_rect().get_center()); await frames(12)
	ok = ok and inv(item) > have
	note("bought %s at %s: %s (now %d, coins %d)" % [item, id, ok, inv(item), Shop.coins(game.state)])
	await tap(KEY_ESCAPE); await frames(8)
	return ok

func top_up(item: String, need: int) -> bool:
	var short := need - inv(item)
	if short <= 0: return true
	var per := 5 if item in ["wood", "stone"] else 1
	var seller := "marta" if item in ["wood", "stone"] else "mario"
	return await buy(seller, item, int(ceil(float(short) / per)))

func nap_until(h: int) -> bool:
	var p: Vector3 = game.player.pos
	var best := {}
	for f in Data.layout.features:
		if f.kind == "bench" and (best.is_empty() or Vector2(f.x - p.x, f.z - p.z).length() < Vector2(best.x - p.x, best.z - p.z).length()): best = f
	await walk_to(best.x, best.z, 1.1)
	var ok := await sleep_at(best.id, h)
	await frames(20)
	return ok

func next_wake(gap: float) -> int:
	for w in [6, 9, 12, 18, 21]:
		if fposmod(w - hour(), 24.0) >= gap: return w
	return 6

func daytime() -> void:
	if hour() >= 20.0 or hour() < 7.5: await nap_until(9)

func wait_until(h: float, max_s: float = 3600.0) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		var now := hour()
		if now >= h and now < h + 1.0: return
		await wait(1.0)

func gather_more(kind: String, test: Callable, only: Array = [], rounds: int = 30) -> bool:
	var unreachable := {}
	for r in rounds:
		if test.call(): return true
		var p: Vector3 = game.player.pos
		var ready: Array = Data.layout.nodes.filter(func(n): return n.kind == kind and (only.is_empty() or only.has(n.id)) and game.actions.ready(n) and not unreachable.has(n.id))
		if ready.is_empty():
			var waiting: bool = Data.layout.nodes.any(func(n): return n.kind == kind and (only.is_empty() or only.has(n.id)) and not unreachable.has(n.id) and WorldActions.regrows(n))
			if not waiting: note("no %s left that can be reached" % kind); break
			note("nothing to %s has grown back: nap" % kind); await nap_until(next_wake(4.0)); continue
		ready.sort_custom(func(a, b): return Vector2(a.x - p.x, a.z - p.z).length() < Vector2(b.x - p.x, b.z - p.z).length())
		note("gather %s (%d) wood=%d stone=%d clay=%d" % [ready[0].id, r, inv("wood"), inv("stone"), inv("clay")])
		if not await gather_node(ready[0].id): unreachable[ready[0].id] = true; note("could not reach %s" % ready[0].id)
	return test.call()

func gather_item(item: String, need: int, rounds: int = 20) -> bool:
	var ids: Array = Data.layout.nodes.filter(func(n): return n.get("gives", {}).has(item)).map(func(n): return n.id)
	var kind: String = Data.node_def(ids[0]).kind
	return await gather_more(kind, func(): return inv(item) >= need, ids, rounds)

func open_build(zone_id: String) -> void:
	await tap(KEY_B); await frames(5)
	for i in 40:
		if game.build.current_zone.get("id", "") == zone_id: break
		game.build.cycle_zone(1); await frames(2)
	game.cam.yaw = 0.35; game.cam.pitch = 1.35; game.cam.dist = 24
	await frames(6)
	if game.build.current_zone.get("id", "") != zone_id: note("build mode didn't reach %s (at %s)" % [zone_id, game.build.current_zone.get("id", "")])

func place_at(i: float, k: float, y: float = 0.1, r: int = -1) -> String:
	if r >= 0:
		for n in 4:
			if game.build.rotation == r: break
			await tap(KEY_R)
	game.build.focus = Vector3(i + 0.5, y, k + 0.5)
	await settle()
	var target := Vector3(i + 0.5, y, k + 0.5)
	for turn in 4:
		if view_clear(target): break
		game.cam.yaw += PI / 2.0
		await settle()
	var p: Vector2 = game.camera.unproject_position(target)
	mouse_move(p); await frames(4)
	var status: String = game.build.status_label.text if game.build.status_label else ""
	await click(p); await frames(3)
	return status

func view_clear(target: Vector3) -> bool:
	var eye: Vector3 = game.camera.global_position
	for n in range(1, 24):
		var q := target.lerp(eye, n / 24.0)
		if q.y < Heightfield.height(q.x, q.z) + 0.05: return false
	return true

func _click_spot(e: Array, ghost: Dictionary) -> Vector3:
	var id := String(e[2])
	var r: int = int(e[3]) if e.size() > 3 else 0
	var fp := BuildGrid.footprint(Data.piece(id), r)
	var i := float(e[0])
	var k := float(e[1])
	if Data.piece(id).get("needsSupport", false): return Vector3(i + 0.12, float(ghost.y), k + 0.12)
	if BuildGrid.ground_at(i, k) < Heightfield.WALKABLE_MIN and float(ghost.y) < 1.5: return Vector3(i + fp.x / 2.0 - 0.5, 0.1, k + fp.y / 2.0 - 0.5)
	return Vector3(i + fp.x / 2.0 - 0.5, float(ghost.y), k + fp.y / 2.0 - 0.5)

func build_plan(qid: String, oid: String) -> int:
	var o := step(qid, oid)
	var zone := Data.zone(String(o.zone))
	await open_build(String(o.zone))
	var placed := 0
	for e in o.plan:
		var id := String(e[2])
		var r: int = int(e[3]) if e.size() > 3 else 0
		var ghost: Dictionary = Plans.lay_out([e], zone, game.state.placements)[0]
		await select_piece(id)
		var before: int = game.state.placements.size()
		var c := _click_spot(e, ghost)
		var status := await place_at(c.x, c.z, c.y, r)
		var ok: bool = game.state.placements.size() > before
		if ok: placed += 1
		var cand: Dictionary = game.build.candidate() if not ok else {}
		note("%s: %s at %d, %d (y %.2f, r %d): %s %s%s" % [qid, id, int(e[0]), int(e[1]), float(ghost.y), r, ok, status, "" if ok else " hover %s cand %s" % [str(game.build.hover.get("point", "")), str(cand)]])
	await leave_build()
	return placed

func plant(zone_id: String, id: String, i: int, k: int) -> bool:
	await open_build(zone_id)
	await select_piece(id)
	var before: int = game.state.placements.size()
	var y := BuildGrid.ground_at(i, k)
	var status := await place_at(i, k, y, 0)
	var ok: bool = game.state.placements.size() > before
	var cand: Dictionary = game.build.candidate() if not ok else {}
	await leave_build()
	note("planted %s at %d, %d in %s: %s %s%s" % [id, i, k, zone_id, ok, status, "" if ok else " hover %s cand %s vines %d" % [str(game.build.hover.get("point", "")), str(cand), inv("cliffs_vine")]])
	return ok

func requests() -> void:
	var from := String(game.shot_cfg.get("from", "welcome"))
	var k0 := SECTIONS.find(from)
	if k0 > 0:
		var saved: Dictionary = SaveSystem.read("cl_" + SECTIONS[k0 - 1])
		if saved.is_empty(): check("from", "A checkpoint to start from", false, "no cl_%s" % SECTIONS[k0 - 1]); return
		game.load_state(saved)
		await await_rebuild(20.0)
		await frames(20)
	var k1 := SECTIONS.find(String(game.shot_cfg.get("to", "easter")))
	for k in range(maxi(k0, 0), (k1 if k1 >= 0 else SECTIONS.size() - 1) + 1):
		note("section %s: day %d %s, %s" % [SECTIONS[k], int(game.state.time.day), Clock.text(game.state.time), reading()])
		await call("sec_" + SECTIONS[k])
		SaveSystem.write("cl_" + SECTIONS[k], game.snapshot())

func sec_welcome() -> void:
	await talk(P + "marta", true, P + "welcome")
	var accepted: bool = qs("welcome") == "active"
	await talk(P + "nunzia")
	await talk(P + "giacomo")
	await talk(P + "aurelio")
	var met_three: bool = stage("welcome") >= 1
	await talk(P + "mario")
	await gather_more("chop", func(): return inv("wood") >= 3, TREES)
	await gather_more("mine", func(): return inv("stone") >= 3)
	await daytime()
	await talk(P + "settimio")
	check("w1", "Welcome to Serenza: off the train with Marta, Capo Horn, Nunzia, Don Aurelio and Trenin met, wood and stone gathered, and it ends with Settimio at his vines",
		accepted and met_three and qs("welcome") == "done" and flag("welcomed") and reading() == "2 of 16 terraces", "%s, stage %d, %s" % [qs("welcome"), stage("welcome"), reading()])

func sec_hut() -> void:
	await daytime()
	await talk(P + "settimio", true, P + "hut")
	var accepted: bool = qs("hut") == "active" and game.state.blueprints.has("vinePergola") and inv("cliffs_vine") >= 2
	await go("plotE4")
	await walk_direct(24.1, -40.9, 0.3, 15.0)
	for b in [["cliffs_bramble1", 24.1, -40.9], ["cliffs_bramble0", 24.1, -40.9], ["cliffs_bramble2", 17.3, -41.2]]:
		if Vector2(game.player.pos.x - float(b[1]), game.player.pos.z - float(b[2])).length() > 0.6: await walk_to(float(b[1]), float(b[2]), 0.4)
		var n := Data.node_def(String(b[0]))
		if await face_and_press(String(b[0]), n.x, n.z):
			await frames(6)
			if game.mode == "minigame": await play_minigame()
			await frames(20)
	var brambles: bool = ["cliffs_bramble0", "cliffs_bramble1", "cliffs_bramble2"].all(func(b): return game.state.nodes.get(b, {}).get("done", false))
	await gather_more("chop", func(): return inv("wood") >= 9 and step_done("hut", "wood") and step_done("hut", "brambles"), TREES)
	await gather_more("mine", func(): return inv("stone") >= 4)
	await go("hut")
	var placed := await build_plan("hut", "hut")
	var roofed: bool = must_met("hut", "hut", 0) and must_met("hut", "hut", 1) and must_met("hut", "hut", 2)
	await shot("the-hut-roofed")
	await go("plotE4")
	placed += await build_plan("hut", "vines")
	await talk(P + "settimio")
	var wardrobe: bool = flag("hutHome")
	check("h1", "The Hut on the Terrace: brambles cut, a roof on pillars, a door and a lamp on the ruin, vines on E4, and E4 counts on the meter",
		accepted and brambles and roofed and placed >= 7 and qs("hut") == "done" and terrace("e4") and pts() == 1 and wardrobe and flag("homePlot"),
		"brambles=%s roofed=%s placed=%d %s e4=%s %s" % [brambles, roofed, placed, qs("hut"), terrace("e4"), reading()])

func sec_wall() -> void:
	await daytime()
	await talk(P + "settimio", true, P + "wall")
	var accepted: bool = qs("wall") == "active" and game.state.blueprints.has("drystoneWall")
	await gather_more("mine", func(): return inv("stone") >= 12 and step_done("wall", "stone"))
	await daytime()
	await talk(P + "settimio")
	await go("tW3w")
	await walk_direct(-27.5, -36.0, 0.3, 15.0)
	var placed := await build_plan("wall", "wall")
	var sealed: bool = must_met("wall", "wall", 0) and must_met("wall", "wall", 1)
	await shot("the-first-wall")
	var w3 := await plant("cliffs_terrace_w3", "vinePergola", -16, -36)
	await go("tW4w")
	var w4 := await plant("cliffs_terrace_w4", "vinePergola", -22, -40)
	var back: bool = terrace("w3") and terrace("w4")
	await daytime()
	await talk(P + "settimio")
	check("w2", "The First Wall: twelve stones quarried, two dry-stone courses close the gap under W4, a vine either side, and W3 and W4 come back",
		accepted and placed == 10 and sealed and w3 and w4 and back and qs("wall") == "done" and pts() == 3 and flag("wallBuilt"),
		"placed=%d sealed=%s w3=%s w4=%s %s %s" % [placed, sealed, w3, w4, qs("wall"), reading()])

func sec_monorail() -> void:
	await daytime()
	await talk(P + "mario", true, P + "monorail")
	var accepted: bool = qs("monorail") == "active"
	await buy("mario", "metal", 1)
	await gather_more("chop", func(): return inv("wood") >= 6, TREES)
	await gather_more("mine", func(): return inv("stone") >= 2)
	await go("rail5")
	var placed := await build_plan("monorail", "slip")
	var way: bool = must_met("monorail", "slip", 0)
	await walk_direct(14.5, -46.0, 0.5, 20.0)
	await walk_direct(14.5, -50.6, 0.5, 20.0)
	var climbed: bool = game.player.pos.y > 21.6 and game.player.pos.z < -49.5
	await shot("up-the-slip")
	await daytime()
	await talk(P + "mario")
	var rebuilt := await await_rebuild()
	check("m1", "The Monorail: stairs on a block up the slip with a railing and a lever, you climb it, the rail is laid and E5 and E6 come back",
		accepted and placed == 5 and way and climbed and rebuilt and qs("monorail") == "done" and Data.world_flags.has("cliffs_monorailRuns") and terrace("e5") and terrace("e6") and pts() == 5,
		"placed=%d way=%s climbed=%s at %s rebuilt=%s %s %s" % [placed, way, climbed, where(), rebuilt, qs("monorail"), reading()])

func sec_cellar() -> void:
	await daytime()
	await talk(P + "marta", true, P + "cellar")
	var accepted: bool = qs("cellar") == "active"
	await gather_more("chop", func(): return inv("wood") >= 10, TREES)
	await walk_to(spot("cliffs_cellar:spot").x, spot("cliffs_cellar:spot").y, 0.6)
	var placed := await build_plan("cellar", "fit")
	var fitted: bool = step_done("cellar", "fit")
	await shot("the-cellar-fitted")
	await go("tE1")
	placed += await build_plan("cellar", "e1")
	await daytime()
	await talk(P + "marta")
	check("k1", "The Cellar Reopens: a counter, two lamps and shelves in the cellar, vines on E1, and the cellar becomes Marta's shop",
		accepted and fitted and placed == 7 and qs("cellar") == "done" and terrace("e1") and pts() == 6 and Shop.is_open(game.state, P + "marta"),
		"fitted=%s placed=%d %s e1=%s %s" % [fitted, placed, qs("cellar"), terrace("e1"), reading()])

func sec_boats() -> void:
	await daytime()
	await talk(P + "giacomo", true, P + "boats")
	var accepted: bool = qs("boats") == "active"
	await top_up("wood", 9)
	await walk_to(-0.5, 28.6, 0.6)
	var placed := await build_plan("boats", "slipway")
	var way: bool = must_met("boats", "slipway", 0)
	await walk_direct(-0.5, 32.6, 0.4, 15.0)
	var out_over: bool = game.player.pos.z > 32.0 and game.player.pos.y > 0.9
	await shot("the-slipway")
	await walk_direct(-0.5, 28.6, 0.5, 15.0)
	await talk(P + "giacomo")
	var done: bool = qs("boats") == "done" and game.state.clothes_owned.has("cliffs_captainCap")
	if not flag("boats_launched"):
		if hour() >= 10.0 or hour() < 5.0: await nap_until(6)
		for n in 60:
			if flag("boats_launched"): break
			await wait(0.5)
	var rebuilt := await await_rebuild()
	var afloat: bool = Data.layout.props.filter(func(p): return String(p.kind) == "cliffs_boat").all(func(p): return p.get("afloat", false))
	await walk_to(0.0, 22.0, 1.0)
	var street := await walk_direct(0.0, 5.0, 0.8, 30.0)
	await walk_to(0.0, 28.0, 1.0)
	await shot("boats-in-the-harbour")
	check("b1", "Boats Back to Sea: planks from the square out over the water, the captain's cap, and at dawn the boats ride in the harbour and the main street opens up",
		accepted and placed >= 6 and way and out_over and done and rebuilt and afloat and street,
		"placed=%d way=%s out=%s done=%s rebuilt=%s afloat=%s street=%s" % [placed, way, out_over, done, rebuilt, afloat, street])

func sec_path() -> void:
	await daytime()
	await talk(P + "aurelio", true, P + "path")
	var accepted: bool = qs("path") == "active"
	await top_up("wood", 8)
	await top_up("stone", 6)
	await go("muleGullyS")
	var placed := await build_plan("path", "gully")
	var way: bool = must_met("path", "gully", 0)
	await walk_direct(-48.5, -36.0, 0.4, 15.0)
	await walk_direct(-48.5, -40.8, 0.4, 20.0)
	var climbed: bool = game.player.pos.y > 19.6 and game.player.pos.z < -40.0
	await shot("the-gully-steps")
	var bell := spot("cliffs_sanctuary:spot")
	await walk_to(bell.x, bell.y, 0.6)
	await walk_direct(-56.0, -56.6, 0.4, 10.0)
	var rang: bool = await face_and_press("cliffs_bell", -56.4, -56.2)
	await frames(10)
	await daytime()
	await talk(P + "aurelio")
	check("p1", "The Sanctuary Path: steps up the gully with railings, you climb them, ring the sanctuary bell, and W7 comes back",
		accepted and placed == 8 and way and climbed and rang and qs("path") == "done" and terrace("w7") and pts() == 7,
		"placed=%d way=%s climbed=%s rang=%s %s %s" % [placed, way, climbed, rang, qs("path"), reading()])

func sec_herbs() -> void:
	await daytime()
	await talk(P + "nunzia", true, P + "herbs")
	var accepted: bool = qs("herbs") == "active"
	await gather_item("cliffs_greens", 8)
	await gather_item("cliffs_borage", 3)
	await daytime()
	await talk(P + "nunzia")
	var paid: bool = stage("herbs") >= 2
	await go("tW2")
	var placed := await build_plan("herbs", "w2")
	await daytime()
	await talk(P + "nunzia")
	check("e1", "Herbs for the Easter Pie: greens and borage off the terraces for Nunzia, two vines on W2, the pie on her counter, and W2 comes back",
		accepted and paid and placed == 2 and qs("herbs") == "done" and terrace("w2") and pts() == 8 and inv("cliffs_pie") >= 2,
		"paid=%s placed=%d %s w2=%s %s" % [paid, placed, qs("herbs"), terrace("w2"), reading()])

func sec_tables() -> void:
	await daytime()
	await talk(P + "nunzia", true, P + "tables")
	var accepted: bool = qs("tables") == "active"
	await top_up("wood", 12)
	await top_up("stone", 4)
	await walk_to(5.5, 26.8, 0.6)
	var placed := await build_plan("tables", "tables")
	await shot("tables-for-the-guests")
	await talk(P + "nunzia")
	check("e2", "Tables for the Guests: two tables, four chairs and a roof on pillars on the harbour square",
		accepted and placed == 10 and qs("tables") == "done", "placed=%d %s" % [placed, qs("tables")])

func sec_lunch() -> void:
	await daytime()
	await talk(P + "giacomo", true, P + "lunch")
	var accepted: bool = qs("lunch") == "active"
	var fish: Array = ["cliffs_fish0", "cliffs_fish1", "cliffs_fish2", "cliffs_fish3"]
	for n in 30:
		if inv("cliffs_bream") >= 3 and inv("cliffs_mullet") >= 2: break
		await gather_node(fish[n % fish.size()])
	var caught: bool = inv("cliffs_bream") >= 3 and inv("cliffs_mullet") >= 2
	var catch_text := "bream=%d mullet=%d" % [inv("cliffs_bream"), inv("cliffs_mullet")]
	await daytime()
	await talk(P + "nunzia")
	if qs("lunch") != "done": await talk(P + "nunzia")
	check("e3", "Fish for the Easter Lunch: three sea bream and two grey mullet caught off the harbour, handed to Nunzia, and the espadrilles",
		accepted and caught and qs("lunch") == "done" and game.state.clothes_owned.has("cliffs_espadrilles"), "caught %s, %s" % [catch_text, qs("lunch")])

func sec_swim() -> void:
	await daytime()
	await talk(P + "aurelio", true, P + "swim")
	var accepted: bool = qs("swim") == "active"
	await top_up("wood", 9)
	await top_up("stone", 2)
	await gather_more("clay", func(): return inv("clay") >= 1)
	await walk_to(23.5, 36.6, 0.5)
	var placed := await build_plan("swim", "ladder")
	var way: bool = must_met("swim", "ladder", 0)
	await walk_direct(23.5, 38.4, 0.3, 10.0)
	await walk_direct(23.5, 41.8, 0.3, 20.0)
	var down: bool = game.player.pos.z > 41.0 and game.player.pos.y < 0.3 and game.player.pos.y > -0.3
	await shot("down-to-the-water")
	await walk_direct(23.5, 38.6, 0.3, 20.0)
	await walk_direct(23.5, 36.6, 0.3, 10.0)
	var up_again: bool = game.player.pos.y > 2.4
	if hour() < 5.0 or hour() >= 7.0: await nap_until(6)
	await talk(P + "aurelio")
	check("s1", "Don Aurelio's Morning Swim: a pontoon and steps down the rocks, you walk down to the water and back, and at dawn he swims",
		accepted and placed == 6 and way and down and up_again and qs("swim") == "done" and flag("swimDone"),
		"placed=%d way=%s down=%s up=%s %s" % [placed, way, down, up_again, qs("swim")])

func sec_shelter() -> void:
	await daytime()
	await talk(P + "fulvio", true, P + "shelter")
	var accepted: bool = qs("shelter") == "active"
	await top_up("wood", 7)
	await top_up("stone", 4)
	if inv("flowers") < 2: await gather_more("flowers", func(): return inv("flowers") >= 2, ["cliffs_broom0", "cliffs_broom1", "cliffs_broom2"])
	await gather_more("clay", func(): return inv("clay") >= 1)
	await go("shelter")
	await walk_direct(-18.6, 2.6, 0.3, 10.0)
	var placed := await build_plan("shelter", "shelter")
	await shot("the-shelter")
	if hour() < 20.0: await nap_until(21)
	await talk(P + "fulvio")
	check("s2", "A Shelter for the Last Train: pillars, a roof, a bench and a lamp at the end of the platform, and Sturlese naps in it after the last train",
		accepted and placed == 6 and qs("shelter") == "done" and flag("shelterBuilt"), "placed=%d %s at %s" % [placed, qs("shelter"), Clock.text(game.state.time)])

func sec_easter() -> void:
	await daytime()
	await talk(P + "marta", true, P + "easter")
	var accepted: bool = qs("easter") == "active"
	var ten: bool = step_done("easter", "terraces")
	await top_up("wood", 6)
	await top_up("stone", 6)
	await gather_more("clay", func(): return inv("clay") >= 1)
	await go("halfway")
	var placed := await build_plan("easter", "rest")
	var rest: bool = flag("restBuilt")
	await shot("the-resting-place")
	await go("square")
	await nap_until(6)
	await talk(P + "aurelio")
	var procession: bool = step_done("easter", "procession")
	await shot("easter-morning")
	if hour() < 13.0: await nap_until(12)
	await wait_until(13.2)
	await talk(P + "settimio")
	check("f1", "Easter on the Terraces: ten terraces in use, the resting place halfway up, the procession on Easter morning and the vote in the cellar",
		accepted and ten and placed == 7 and rest and procession and qs("easter") == "done" and game.state.flags.get("olive_village_revealed", false),
		"ten=%s placed=%d rest=%s procession=%s %s %s" % [ten, placed, rest, procession, qs("easter"), reading()])
	await go("ferry")
	var ferry: bool = game.interactables.any(func(it): return String(it.get("id", "")) == "cliffs_ferry" and (not it.has("available") or it.available.call()))
	check("f2", "After the finale the ferry calls at the landing", ferry, where())
	await after_the_finale()

func after_the_finale() -> void:
	var an := animals()
	var T: Script = load("res://scripts/locations/cliffs/terraces.gd")
	var gone := true
	var bad := ""
	for id in T.ORDER:
		var g: Node3D = game.village.find_child("brambles_" + String(id), true, false)
		if g == null or g.visible == terrace(String(id)):
			gone = false
			bad += String(id) + " "
	check("f3", "The brambles are gone from every terrace that came back, and only from those", gone, bad)
	var A: Script = load("res://scripts/locations/cliffs/animals.gd")
	var use: Array = A.in_use(game.state)
	var basking: int = an.lizards.filter(func(l): return use.has(String(l.terrace))).size() if an else 0
	check("f4", "Lizards now bask on the walls of every terrace in use (%d terraces)" % use.size(), use.size() >= 10 and basking == 2 * use.size(), "%d lizards" % basking)
	var swallows: int = an.swallows.filter(func(sw): return (sw.obj as Node3D).visible).size() if an else 0
	check("f5", "And swallows fill the sky over the harbour", swallows == 16, "%d at %s" % [swallows, Clock.text(game.state.time)])
	await wait(2.0)
	var hk: Node = game.village.get_node_or_null("cliffs_hikers")
	var walking: Array = hk.walkers.filter(func(w): return (w.chibi as Node3D).visible) if hk else []
	check("f6", "Walkers in red anoraks come for the path after Easter", walking.size() == 8, "%d at %s" % [walking.size(), Clock.text(game.state.time)])
	if not walking.is_empty():
		var c: Node3D = walking[0].chibi
		await view(c.position.x, c.position.z, 0.6, 0.45, 9.0, hour(), "hikers-on-the-path")
