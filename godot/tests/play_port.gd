extends "full_base.gd"

const Port := preload("../scripts/locations/port.gd")
const EARLIER := ["hearthglow", "river_town", "rice_village", "metropolis"]

var n := 0

func step(label: String, ok: bool, detail: String = "") -> void:
	n += 1
	check(n, label, ok, detail)

func at(node: String, tol: float = 1.6) -> bool:
	var p: Array = Data.layout.nav_nodes[node]
	return Vector2(game.player.pos.x - p[0], game.player.pos.z - p[1]).length() < tol

func go(node: String) -> bool:
	var p: Array = Data.layout.nav_nodes[node]
	await walk_to(p[0], p[1], 1.0)
	note("at %s: %s" % [node, game.player.pos])
	return at(node)

func here() -> String: return Port.level(game.player.pos.x, game.player.pos.z)

func feet() -> float: return game.player.pos.y

func look(yaw: float, pitch: float, dist: float) -> void:
	game.cam.yaw = yaw; game.cam.pitch = pitch; game.cam.dist = dist
	game.cam.update(0.016, game.player.pos); game.cam.snap()
	await frames(4)

func building(id: String) -> Dictionary:
	return Data.layout.buildings.filter(func(b): return b.id == id)[0]

func inside(id: String) -> bool:
	var b := building(id)
	return Interiors.inside(b, Port.base_of(b), game.player.pos)

func enter(id: String, name: String) -> bool:
	var spot: Array = Data.layout.nav_nodes.get(id + ":spot", [])
	if spot.is_empty(): return false
	await walk_to(spot[0], spot[1], 0.7)
	await wait(1.0)
	await shot(name)
	return inside(id) and float(game.roof_fade.get(id, 1.0)) < 0.2

func await_rebuild(max_s: float = 60.0) -> bool:
	var old_id: int = game.get_instance_id()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		await frames(2)
		var cur = get_tree().current_scene
		if cur != null and cur.get_instance_id() != old_id and cur.get("started") == true:
			game = cur
			await frames(30)
			return true
	return false

func ride(from: String, to: String, approach: Vector2 = Vector2.INF) -> bool:
	var a := feature(from); var b := feature(to)
	var spot := approach if approach != Vector2.INF else Vector2(a.x + 1.0, a.z + (1.2 if a.z < 0 else -1.2))
	await walk_to(spot.x, spot.y, 0.8)
	if not await face_and_press(a.id, a.x, a.z): return false
	await frames(8)
	var btn := game.panels.find_child("ride_" + b.id, true, false) as Button
	if btn == null:
		note("no ride button for %s in panel '%s'" % [to, game.panels.current])
		return false
	await click(btn.get_global_rect().get_center())
	for k in 300:
		await frames(2)
		if game.mode == "explore" and Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0: break
	await frames(10)
	return Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0

func step_tour() -> void:
	await arrive_as_if_played(EARLIER)
	game.state.time.minute = 10 * 60.0
	await frames(10)
	step("the game is in Tonnarella", Data.island == "port", Data.island)
	var ar: Dictionary = Data.layout.arrive
	var off := Vector2(game.player.pos.x - ar.x, game.player.pos.z - ar.z).length()
	step("off the train on the station forecourt, at the top", off < 1.0 and absf(feet() - Port.TOP_H) < 0.05, str(game.player.pos))
	step("Toriano's finale is behind you and Tonnarella is on the travel map", game.state.flags.get("metropolis_angel_lit", false) and Travel.on_map(Data.island_def("port"), game.state.flags, "port"))
	var chip := game.hud_res.find_child("res_coins", true, false) as Control
	var wallet: String = (chip.get_child(0) as Label).text if chip else "no chip"
	step("the wallet shows lire and euros in Tonnarella", wallet.contains(" lire (€"), wallet)
	await look(PI, 0.35, 12.0)
	await shot("arrival")

	step("across the top to the belvedere", await go("port_belvedere") and here() == "top")
	await look(2.6, 0.45, 14.0)
	await shot("belvedere")
	step("down the stair lane to the church square", await go("port_square") and here() == "middle" and absf(feet() - Port.MID_H) < 0.1, str(game.player.pos))
	await look(0.0, 0.4, 9.0)
	await shot("church-square")
	step("along the main alley to Nonna Pina's door", await go("port_nonna_door"))
	await look(0.2, 0.25, 7.0)
	await shot("nonna-balcony")
	step("and back east to the door of your palazzo", await go("port_home_door"))
	var flat := building("port_flat")
	step("up the 112 steps to the roof", await ride("port_stairs_street", "port_stairs_roof") and absf(feet() - float(flat.y)) < 0.1, str(game.player.pos))
	step("into your flat under the slates", await enter("port_flat", "your-flat"), str(game.player.pos))
	var door_in: Array = Data.layout.nav_nodes["port_flat:in"]
	await walk_direct(door_in[0], door_in[1], 0.5)
	await go("port_roof")
	await go("port_roof_e")
	await walk_direct(46.0, -5.0, 0.8, 5.0)
	step("the railing keeps you on the roof terrace", absf(feet() - float(flat.y)) < 0.1 and game.player.pos.x < 41.0, str(game.player.pos))
	await look(2.4, 0.35, 10.0)
	await shot("roof-terrace")
	step("and down the 112 steps again", await ride("port_stairs_roof", "port_stairs_street", Vector2(38.6, -9.9)) and absf(feet() - Port.MID_H) < 0.1, str(game.player.pos))
	step("to the lookout at the end of the alley", await go("port_alley_e3"))
	await walk_direct(66.0, 0.0, 0.8, 6.0)
	step("the parapet at the alley's end holds", here() == "middle" and game.player.pos.x < 56.0 and absf(feet() - Port.MID_H) < 0.1, str(game.player.pos))

	step("down the lane by the fish market", await go("port_laneB3_foot") and feet() < 2.0, str(game.player.pos))
	step("along the arcades to Rosetta's bakery", await go("port_bakery_door") and here() == "quay" and absf(feet() - Port.QUAY_H) < 0.1, str(game.player.pos))
	await look(0.35, 0.3, 12.0)
	await shot("arcades")
	step("into Rosetta's bakery", await enter("port_bakery", "bakery"), str(game.player.pos))
	step("out and into the savings bank", await enter("port_bank", "bank"), str(game.player.pos))
	step("along the quay into the harbour office", await enter("port_harbour_office", "harbour-office"), str(game.player.pos))
	step("out along the breakwater to the gap", await go("port_breakwater_n") and here() == "breakwater", str(game.player.pos))
	var r: Array = Data.layout.nav_nodes["port_rock"]
	await walk_direct(r[0], r[1], 0.8, 8.0)
	step("the gap stops you short of the lighthouse", here() == "breakwater" and game.player.pos.z < Port.GAP_Z.x and feet() > Heightfield.WALKABLE_MIN, str(game.player.pos))
	await look(PI, 0.4, 16.0)
	await shot("the-gap")

	note("test-only: the script steps over the gap here; the breakwater is mended in its request")
	var across: Array = Data.layout.nav_nodes["port_breakwater_s"]
	game.player.teleport(across[0], across[1])
	await frames(10)
	step("into the keeper's room at the foot of the lighthouse", await enter("port_keeper", "keepers-room"), str(game.player.pos))
	var lantern := building("port_lantern")
	step("round to the lighthouse door and up to the gallery", await ride("port_lantern_foot", "port_lantern_top", Vector2(41.9, 88.6)) and absf(feet() - float(lantern.y)) < 0.1, str(game.player.pos))
	step("into the lantern room", await enter("port_lantern", "lantern-room"), str(game.player.pos))
	var lantern_in: Array = Data.layout.nav_nodes["port_lantern:in"]
	await walk_direct(lantern_in[0], lantern_in[1], 0.5)
	await go("port_gallery")
	await walk_direct(44.2, 86.6, 0.5)
	await walk_direct(44.2, 76.0, 0.8, 4.0)
	step("the gallery's railing holds", absf(feet() - float(lantern.y)) < 0.1, str(game.player.pos))
	await look(2.8, 0.25, 9.0)
	await shot("gallery")
	step("down the lighthouse stair", await ride("port_lantern_top", "port_lantern_foot", Vector2(40.8, 86.6)) and feet() < 3.0, str(game.player.pos))
	var back: Array = Data.layout.nav_nodes["port_breakwater_n"]
	game.player.teleport(back[0], back[1])
	await frames(10)

	step("round the tip to the east rocks under the castle", await go("port_rocks_n") and here() == "rocks", str(game.player.pos))
	await look(-PI / 2.0, 0.3, 16.0)
	await shot("east-rocks")
	await walk_direct(50.0, game.player.pos.z, 0.8, 6.0)
	step("the cliff under the castle can't be climbed", here() == "rocks" and feet() < 2.0, str(game.player.pos))
	step("all the way back up to the castle gate", await go("port_castle_gate") and here() == "top" and absf(feet() - Port.TOP_H) < 0.1, str(game.player.pos))
	await look(-0.6, 0.3, 16.0)
	await shot("castle")

	var train := feature("port_train")
	step("back to the station", await go("port_station"))
	step("the train is the way out", await face_and_press("port_train", train.x, train.z))
	await frames(10)
	var mv = game.panels.find_child("map_view", true, false)
	step("and it opens the travel map", mv != null and (mv as Control).is_visible_in_tree(), String(game.panels.current))
	game.panels.close()
	await frames(6)

	note("test-only: the lift's flag is set directly here; the request that powers it comes with the people and requests")
	step("no lift stops before the lift runs", not Data.layout.features.any(func(f): return f.kind == "stop" and f.get("line", "") == "port_lift"))
	game.set_flag("port_lift_on")
	step("the place is built again with the lift running", await await_rebuild())
	step("three lift stops", Data.layout.features.filter(func(f): return f.kind == "stop" and f.get("line", "") == "port_lift").size() == 3)
	step("ride the lift from the castle down to the harbour", await ride("port_lift_castle", "port_lift_harbour") and here() == "quay", str(game.player.pos))
	step("and up to the church square", await ride("port_lift_harbour", "port_lift_church") and here() == "middle", str(game.player.pos))
	game.state.time.minute = 21 * 60.0
	await wait(2.0)
	await look(0.4, 0.3, 14.0)
	await shot("square-at-night")

const STEPS := ["tour", "welcome", "errands", "breakwater", "lampara", "fishmarket", "labels", "lift", "nonna", "lighthouse"]
const PP := "port_"
const DRIFTWOOD := ["port_driftwood0", "port_driftwood1", "port_driftwood2", "port_driftwood3", "port_driftwood4", "port_driftwood5"]
const RUBBLE := ["port_rubble0", "port_rubble1", "port_rubble2"]
const WASH_OWNERS := {"tablecloth": "pina", "shirt": "lorenzo", "longjohns": "giobatta", "apron": "rosetta", "gloves": "agostino"}

func play() -> void:
	var from: String = String(game.shot_cfg.get("from", "tour"))
	var first := maxi(STEPS.find(from), 0)
	if first > 1:
		var slot := checkpoint(STEPS[first - 1])
		var old_id: int = game.get_instance_id()
		check("resume", "picks up from the checkpoint after %s" % STEPS[first - 1], game.load_from(slot), slot)
		await settle_scene(old_id)
		note("resumed at %s: %s, changeover %d%%" % [from, Clock.text(game.state.time), meter()])
	for i in range(first, STEPS.size()):
		if STEPS[i] == "welcome": await fresh_arrival()
		await call("step_" + STEPS[i])
		if STEPS[i] != "tour": game.save_to(checkpoint(STEPS[i]))
	await finale_checks()

func checkpoint(step_id: String) -> String: return "port_after_" + step_id

func settle_scene(old_id: int) -> void:
	for k in 600:
		await frames(2)
		var cur = get_tree().current_scene
		if cur != null and cur.get("started") == true:
			if cur.get_instance_id() != old_id: game = cur
			break
	await frames(30)

func fresh_arrival() -> void:
	var old_id: int = game.get_instance_id()
	game.load_state(Progress.as_if_played(EARLIER, "port", String(game.state.get("name", "Pip"))))
	await settle_scene(old_id)
	game.state.time.minute = 10 * 60.0
	await frames(20)
	note("arrived as if %s were played: %s, %d plans, off the 10 AM train" % [str(EARLIER), Money.lire(inv("coins")), game.state.blueprints.size()])

func who(id: String) -> String: return PP + id
func status(qid: String) -> String: return String(game.state.quests.get(PP + qid, {}).get("status", ""))
func done(qid: String) -> bool: return status(qid) == "done"
func step_done(qid: String, oid: String) -> bool: return game.state.quests.get(PP + qid, {}).get("done", {}).has(oid)
func meter() -> int: return LocationMeter.points(game.state, "port")
func hour() -> float: return float(game.state.time.minute) / 60.0
func flag(f: String) -> bool: return bool(game.state.flags.get(f, false))
func wallet() -> String:
	var chip := game.hud_res.find_child("res_coins", true, false) as Control
	return (chip.get_child(0) as Label).text if chip else ""

func converse(id: String, accept: bool, choose: String = "") -> bool:
	for k in 20:
		if game.mode == "dialogue": break
		await frames(2)
	if game.mode != "dialogue": note("no dialogue with %s" % id); return false
	var picked := false
	for k in 300:
		await frames(4)
		if not is_instance_valid(game) or game.mode != "dialogue": return true
		var ui: DialogueUI = game.dialogue
		if ui.choices.is_empty():
			await tap(KEY_E)
			continue
		var idx := -1
		if choose != "" and not picked:
			for i in ui.choices.size():
				if ui.choices[i].kind == choose: idx = i; picked = true; break
		if idx < 0 and accept:
			for i in ui.choices.size():
				if str(ui.choices[i].label).begins_with("✨") or ui.choices[i].kind == "pay": idx = i; break
		if idx < 0:
			for i in ui.choices.size():
				if ui.choices[i].kind == "bye": idx = i
		await tap(game.dialogue.key_for(idx))
	return true

func chat(npc: String, accept: bool = true, choose: String = "") -> bool:
	var id := PP + npc
	for attempt in 6:
		if not is_instance_valid(game): return true
		var a = game.npcs[id]
		if not a.waypoints.is_empty() and Data.layout.nav_nodes.has(a.goal):
			var g: Array = Data.layout.nav_nodes[a.goal]
			if Vector2(a.pos.x - g[0], a.pos.z - g[1]).length() > 10.0:
				note("%s is walking to %s: meeting them there" % [npc, a.goal])
				await walk_to(g[0], g[1], 2.0)
				for k in 150:
					if game.npcs[id].waypoints.is_empty(): break
					await wait(1.0)
				continue
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[id]
		if await face_and_press("npc:" + id, a.pos.x, a.pos.z):
			if await converse(id, accept, choose): return true
			if not is_instance_valid(game): return true
			await frames(10)
	note("could not reach %s to talk" % npc)
	return false

func chat_until(npc: String, test: Callable, times: int = 4) -> bool:
	for k in times:
		if test.call(): return true
		await chat(npc)
		await frames(6)
	return test.call()

func accept_all(npc: String) -> void:
	for k in 4:
		if game.story.engine.offers_for(who(npc)).is_empty(): return
		await chat(npc)
		await frames(6)

func buy(npc: String, item: String, times: int) -> int:
	if not await chat(npc, false, "shop"): note("no shop at %s" % npc); return 0
	for k in 30:
		if game.panels.current == "shop": break
		await frames(2)
	var line := -1
	var stock: Array = Shop.def(who(npc)).get("stock", [])
	for i in stock.size():
		if stock[i].get("items", {}).has(item): line = i
	var got := 0
	for k in times:
		var b := game.panels.find_child("buy_%d" % line, true, false) as Button
		if b == null or b.disabled: break
		await click(b.get_global_rect().get_center()); await frames(6); got += 1
	game.panels.close(); await frames(4)
	note("bought %d x %s at %s (%s left)" % [got, item, npc, Money.lire(inv("coins"))])
	return got

func buy_until(npc: String, item: String, want: int) -> void:
	var per := 1
	for l in Shop.def(who(npc)).get("stock", []):
		if l.get("items", {}).has(item): per = int(l.items[item])
	var short := want - inv(item)
	if short > 0: await buy(npc, item, int(ceil(float(short) / per)))

func open_zone(zone_id: String, yaw: float = 0.35) -> bool:
	await tap(KEY_B); await frames(5)
	for k in 16:
		if game.build.current_zone.get("id", "") == PP + zone_id: break
		game.build.cycle_zone(1); await frames(2)
	game.cam.yaw = yaw; game.cam.pitch = 1.05; game.cam.dist = 15
	await frames(6)
	return game.build.current_zone.get("id", "") == PP + zone_id

func turn_view(angle: float) -> void:
	var mid: Vector2 = game.get_viewport().get_visible_rect().size / 2.0
	var px := angle / (0.0055 * float(game.settings.sensitivity))
	var steps := maxi(1, int(ceil(absf(px) / 20.0)))
	mouse_button(mid, MOUSE_BUTTON_RIGHT, true); await frames(1)
	for k in steps:
		mouse_move(mid, Vector2(px / steps, 0)); await frames(1)
	mouse_button(mid, MOUSE_BUTTON_RIGHT, false); await frames(2)

func put(id: String, i: float, k: float, r: int = 0, y: float = 0.3) -> bool:
	await select_piece(id)
	for m in 12:
		if game.build.rotation == r: break
		await tap(KEY_R); await frames(2)
	var fp := BuildGrid.footprint(Data.piece(id), r)
	var aims: Array = [Vector3(i + fp.x / 2.0, y + 0.02, k + fp.y / 2.0)]
	for off in [Vector2(-0.4, -0.4), Vector2(0.4, 0.4), Vector2(-0.4, 0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0, -0.4), Vector2(0, 0.4)]:
		aims.append(aims[0] + Vector3(off.x, 0, off.y))
	game.build.focus = Vector3(aims[0].x, y, aims[0].z)
	var p := Vector2.ZERO
	var on_it := false
	for attempt in 27:
		if attempt > 0 and attempt % 9 == 0: await turn_view(PI / 2.0)
		await settle()
		p = game.camera.unproject_position(aims[attempt % aims.size()])
		mouse_move(p, Vector2(1, 0)); await frames(4)
		var c: Dictionary = game.build.check.get("pl", {})
		if not c.is_empty() and c.id == id and is_equal_approx(float(c.i), i) and is_equal_approx(float(c.k), k) and int(c.r) == r and (y <= 0.3 or absf(float(c.y) - y) < 0.25): on_it = true; break
		await frames(10)
	if not on_it:
		note("could not point at %d,%d (y %.1f) for %s: the cursor is on %s" % [i, k, y, id, game.build.check.get("pl", {})])
		return false
	var status_text: String = game.build.status_label.text if game.build.status_label else ""
	var before: int = game.state.placements.size()
	mouse_button(p, MOUSE_BUTTON_LEFT, true); mouse_button(p, MOUSE_BUTTON_LEFT, false)
	await frames(3)
	var ok: bool = game.state.placements.size() > before and game.state.placements.back().id == id and is_equal_approx(float(game.state.placements.back().i), i) and is_equal_approx(float(game.state.placements.back().k), k)
	if not ok: note("could not place %s at %d,%d (y %.1f): %s" % [id, i, k, y, status_text])
	return ok

func put_all(list: Array) -> int:
	var placed := 0
	for e in list:
		if await put(e[0], e[1], e[2], e[3] if e.size() > 3 else 0, e[4] if e.size() > 4 else 0.3): placed += 1
	return placed

func plan_of(qid: String, y: float, ys: Dictionary = {}) -> Array:
	var o: Dictionary = Data.quest(PP + qid).objectives.filter(func(x): return x.has("plan"))[0]
	return o.plan.map(func(e): return [String(e[2]), int(e[0]), int(e[1]), int(e[3]), float(ys.get(String(e[2]), y))])

func cost_of(list: Array) -> Dictionary:
	var c := {}
	for e in list:
		var pc: Dictionary = Data.piece(String(e[0])).get("cost", {})
		for k in pc: c[k] = int(c.get(k, 0)) + int(pc[k])
	return c

func sleep_until(bench: String, h: int) -> bool:
	var f := feature(PP + bench)
	await walk_to(f.x + 1.2, f.z + 0.6, 0.6)
	return await sleep_at(PP + bench, h)

func ready_count(kind: String, only: Array) -> int:
	return Data.layout.nodes.filter(func(x): return x.kind == kind and only.has(x.id) and game.actions.ready(x)).size()

func chop_until(test: Callable, rounds: int = 14) -> bool:
	return await gather_until("chop", test, DRIFTWOOD, rounds)

func enough_wood(need: Dictionary) -> void:
	await chop_until(func(): return inv("wood") >= int(need.get("wood", 0)))
	if inv("wood") < int(need.get("wood", 0)):
		note("the driftwood ran out for today: buying the rest at the chandlery")
		await buy_until("davide", "wood", int(need.wood))

func mine_until(test: Callable, rounds: int = 8) -> bool:
	return await gather_until("mine", test, RUBBLE, rounds)

func step_welcome() -> void:
	check("nicolo_waits", "Nicolò waits on the forecourt with a request", game.story.marker_for(who("nicolo")) == "offer" and Vector2(game.npcs[who("nicolo")].pos.x + 8.0, game.npcs[who("nicolo")].pos.z + 58.0).length() < 4.0,
		"marker %s at %s" % [game.story.marker_for(who("nicolo")), game.npcs[who("nicolo")].pos])
	await shot("nicolo-on-the-forecourt")
	var coins0 := inv("coins")
	await chat("nicolo")
	check("welcome_on", "Mind the Change starts, with the euro starter kit: 25,000 lire", status("welcome") == "active" and inv("coins") == coins0 + 25, "%s, %s" % [status("welcome"), Money.lire(inv("coins") - coins0)])
	check("kit_both", "the kit shows in both currencies", Money.lire(25) == "25,000 lire (€12.91)", Money.lire(25))
	await chat("nicolo")
	check("welcome_bank", "you follow Nicolò down the stair lanes to the bank", step_done("welcome", "bank"), str(game.state.quests.get(PP + "welcome", {}).get("done", {}).keys()))
	await chat("rosetta")
	check("welcome_focaccia", "Rosetta's focaccia (and a gull)", step_done("welcome", "focaccia") and inv("port_focaccia") >= 1, "focaccia %d" % inv("port_focaccia"))
	await chop_until(func(): return step_done("welcome", "driftwood"), 6)
	check("welcome_driftwood", "you chop driftwood on the east rocks", step_done("welcome", "driftwood"), "wood %d" % inv("wood"))
	await shot("driftwood")
	await chat("lorenzo")
	check("welcome_harbour", "the Comandante shows you the broken breakwater and the dark lighthouse", step_done("welcome", "harbour") and flag("port_lorenzo_met"))
	await ride("port_stairs_street", "port_stairs_roof")
	for k in 20:
		if step_done("welcome", "steps"): break
		await frames(2)
	check("welcome_steps", "you climb the 112 steps to your flat", step_done("welcome", "steps"), str(game.player.pos))
	await ride("port_stairs_roof", "port_stairs_street", Vector2(38.6, -9.9))
	await chat("nicolo")
	check("welcome_done", "Nicolò counted the steps from the street: welcome home", done("welcome") and flag("port_welcomed") and flag("port_home"), status("welcome"))
	check("welcome_meter", "15% of the changeover, and prices in both everywhere", meter() == 15 and flag("port_euro_both") and Money.mode_for(game.state.flags, "hearthglow") == "both",
		"%d%%, %s" % [meter(), Money.mode_for(game.state.flags, "hearthglow")])
	check("hud_meter", "the HUD shows the changeover", game.hud.harmony_label.text == "15%", "%s %s" % [game.hud.harmony_title.text, game.hud.harmony_label.text])

func step_errands() -> void:
	for npc in ["rosetta", "nicolo", "giobatta", "lorenzo", "pina", "agostino"]: await accept_all(npc)
	var asked: Array = ["seagulls", "queue"] + WASH_OWNERS.keys().map(func(w): return "wash_" + w)
	check("errands_on", "the side requests and the washing are taken on", asked.all(func(q): return status(q) == "active"), str(asked.map(func(q): return "%s %s" % [q, status(q)])))
	for w in ["longjohns", "tablecloth", "gloves", "apron", "shirt"]:
		var nd := Data.node_def("port_wash_" + w)
		await gather_node(String(nd.id))
		check("found_" + w, "you find %s" % nd.name, inv("port_wash_" + w) == 1, str(game.player.pos))
	for w in WASH_OWNERS:
		await chat_until(WASH_OWNERS[w], func(): return done("wash_" + w))
		check("back_" + w, "%s, back on the line" % Data.node_def("port_wash_" + w).name, done("wash_" + w), status("wash_" + w))
	var queue := plan_of("queue", 1.2, {"roof": 3.4})
	var gulls := plan_of("seagulls", 1.2, {"roof": 3.4})
	var need := cost_of(queue + gulls)
	if inv("stone") < int(need.get("stone", 0)): await mine_until(func(): return inv("stone") >= int(need.stone))
	await buy_until("davide", "wood", int(need.get("wood", 0)))
	await buy_until("davide", "clay", int(need.get("clay", 0)))
	await buy_until("davide", "crystal", int(need.get("crystal", 0)))
	check("errands_materials", "stone from the castle wall, and timber, roof tiles and copper wire from the chandlery", inv("wood") >= int(need.wood) and inv("stone") >= int(need.stone) and inv("clay") >= int(need.clay) and inv("crystal") >= int(need.crystal), str(need))
	await walk_to(13.0, 31.0, 0.8)
	await open_zone("bank_arcade", 0.0)
	var placed := await put_all(queue)
	await shot("queue-at-the-bank")
	await leave_build()
	check("queue_built", "benches, a roof and a lamp for the queue outside the bank", placed == queue.size() and step_done("queue", "seats"), "%d of %d" % [placed, queue.size()])
	await walk_to(-3.0, 31.0, 0.8)
	await open_zone("bakery_door", 0.0)
	placed = await put_all(gulls)
	await shot("dockers-breakfast")
	await leave_build()
	check("gulls_built", "tables, chairs, a roof and a lamp outside Rosetta's", placed == gulls.size() and step_done("seagulls", "tables"), "%d of %d" % [placed, gulls.size()])
	await chat_until("nicolo", func(): return done("queue"))
	await chat_until("rosetta", func(): return done("seagulls"))
	check("errands_done", "the queue sits down and the dockers eat under a roof", done("queue") and done("seagulls"), "%s %s" % [status("queue"), status("seagulls")])
	check("errands_meter", "the changeover after the errands: 15 + 4 + 4 + 5 = 28%, and Nonna's converter", meter() == 28 and game.state.clothes_owned.has("port_woolcap"), "%d%%" % meter())

func step_breakwater() -> void:
	await chat("lorenzo")
	check("breakwater_on", "the Comandante asks you to mend the breakwater", status("breakwater") == "active", status("breakwater"))
	var extra := [["stoneBlock", 37, 52, 0, 0.4], ["lamp", 40, 62, 0, 0.4], ["bench", 40, 52, 1, 0.4]]
	var need := cost_of(plan_of("breakwater", 0.4) + extra)
	await enough_wood(need)
	await mine_until(func(): return inv("stone") >= int(need.stone))
	check("breakwater_materials", "driftwood from the rocks and stone from the castle wall", step_done("breakwater", "wood") and step_done("breakwater", "stone"), "wood %d stone %d" % [inv("wood"), inv("stone")])
	if inv("crystal") < int(need.get("crystal", 0)): await buy_until("davide", "crystal", int(need.crystal))
	await walk_to(38.6, 49.5, 0.8)
	await open_zone("breakwater", PI)
	var ys := {"bridgePost": 0.1, "railing": 0.55}
	var plan := plan_of("breakwater", 0.4, ys)
	var placed := await put_all(plan)
	var brief: Dictionary = Data.quest(PP + "breakwater").objectives.filter(func(o): return o.id == "bridge")[0]
	game.story.engine.invalidate()
	check("breakwater_built", "planks on a post across the gap, with railings: the brief is met", placed == plan.size() and step_done("breakwater", "bridge") and flag("port_breakwater_done"), "%d of %d" % [placed, plan.size()])
	placed = await put_all(extra)
	await shot("the-mended-breakwater")
	await leave_build()
	var wished: int = game.story.engine.commission(PP + "breakwater", brief).get("wished", 0)
	note("breakwater wishes met: %d of 3 (%d extra pieces placed)" % [wished, placed])
	await walk_direct(39.5, 52.6, 0.4)
	await walk_direct(39.5, 62.4, 0.4)
	check("breakwater_walked", "you walk across the planks to the lighthouse side", game.player.pos.z > 62.0 and feet() > 0.2, str(game.player.pos))
	await walk_direct(40.6, 64.0, 0.6)
	await chat("gerolamo")
	check("breakwater_gerolamo", "Gerolamo, on his rock, hears the way is open", step_done("breakwater", "gerolamo"))
	await chat("lorenzo")
	check("breakwater_done", "the Comandante has nothing to complain about", done("breakwater") and flag("port_breakwater_open"), "%s, %d%%" % [status("breakwater"), meter()])

func step_lampara() -> void:
	await chat("stefano")
	check("lampara_on", "Stefano asks you out under the lampara", status("lampara") == "active" and flag("port_lampara_on"), status("lampara"))
	if hour() < 20.0 and hour() > 5.0: await sleep_until("bench_quay1", 21)
	check("lampara_night", "night falls over the harbour", hour() >= 20.0 or hour() < 4.0, Clock.text(game.state.time))
	for k in 12:
		if step_done("lampara", "fish"): break
		await gather_node("port_lampara_spot")
	await shot("lampara-night")
	check("lampara_fished", "four catches of anchovies under the lamp", step_done("lampara", "fish") and inv("port_anchovy") >= 4, "anchovies %d" % inv("port_anchovy"))
	await sleep_until("bench_quay2", 6)
	await chat("giobatta")
	check("lampara_sold", "Baciccia buys the catch at dawn", step_done("lampara", "sell"), Clock.text(game.state.time))
	await chat_until("stefano", func(): return done("lampara"))
	check("lampara_done", "and Stefano takes his share", done("lampara"), status("lampara"))

func step_fishmarket() -> void:
	await chat_until("giobatta", func(): return status("fishmarket") == "active", 2)
	check("market_on", "Baciccia wants his market back", status("fishmarket") == "active" and inv("clay") >= 1 and inv("metal") >= 1, status("fishmarket"))
	var extra := [["lamp", 30, 26, 0, 1.2], ["bench", 30, 29, 0, 1.2]]
	var plan := plan_of("fishmarket", 1.2, {"roof": 3.4})
	var need := cost_of(plan + extra)
	await enough_wood(need)
	await mine_until(func(): return inv("stone") >= int(need.stone))
	if inv("crystal") < int(need.get("crystal", 0)): await buy_until("davide", "crystal", int(need.crystal))
	check("market_materials", "driftwood and stone for the counters and the roof", step_done("fishmarket", "wood") and step_done("fishmarket", "stone"), "wood %d stone %d" % [inv("wood"), inv("stone")])
	await walk_to(34.0, 33.5, 0.8)
	await open_zone("fishmarket", 0.0)
	var placed := await put_all(plan)
	check("market_built", "three counters, a roof on pillars and a price sign", placed == plan.size() and step_done("fishmarket", "market"), "%d of %d" % [placed, plan.size()])
	await put_all(extra)
	await shot("fish-market")
	await leave_build()
	await chat_until("giobatta", func(): return done("fishmarket"))
	check("market_done", "Baciccia sells under a roof again", done("fishmarket"), "%s, %d%%" % [status("fishmarket"), meter()])

func step_labels() -> void:
	await chat("davide")
	check("labels_on", "Davide wants the arcade's two-price signs", status("labels") == "active", status("labels"))
	var plan := plan_of("labels", 1.2)
	var need := cost_of(plan)
	await buy_until("davide", "metal", int(need.get("metal", 0)))
	await buy_until("davide", "crystal", int(need.get("crystal", 0)))
	await buy_until("davide", "wood", int(need.get("wood", 0)))
	await walk_to(10.0, 27.5, 0.8)
	await open_zone("arcade", 0.0)
	var placed := await put_all(plan)
	await shot("the-arcade-signs")
	await leave_build()
	check("labels_built", "three signs along the arcade and a lamp", placed == plan.size() and step_done("labels", "signs"), "%d of %d" % [placed, plan.size()])
	await chat_until("davide", func(): return done("labels"))
	check("labels_done", "every shop shows both prices", done("labels"), "%s, %d%%" % [status("labels"), meter()])
	check("euros_first", "50%: euros first on every price", meter() >= 50 and flag("port_euro_first") and wallet().contains("€") and wallet().find("€") < wallet().find("lire"), "%d%%, wallet %s" % [meter(), wallet()])

func step_lift() -> void:
	await chat("agostino")
	check("lift_on", "Agostino asks you to bring the lift back", status("lift") == "active", status("lift"))
	var extra := [["lamp", 28, -40, 0, 20.0], ["bench", 30, -40, 0, 20.0]]
	var plan := plan_of("lift", 20.0)
	var need := cost_of(plan + extra)
	await buy_until("davide", "fabric", int(need.get("fabric", 0)))
	if inv("crystal") < int(need.get("crystal", 0)): await buy_until("davide", "crystal", int(need.crystal))
	await enough_wood(need)
	check("lift_materials", "driftwood, and sailcloth from the chandlery", step_done("lift", "wood") and step_done("lift", "fabric"), "wood %d fabric %d" % [inv("wood"), inv("fabric")])
	await walk_to(28.0, -38.0, 0.8)
	await open_zone("bastion", 0.0)
	var placed := await put_all(plan)
	await frames(30)
	check("lift_powered", "a windmill on the bastion drives the lift", placed == plan.size() and step_done("lift", "power") and game.mech.fed.get(PP + "lift", false), "%d placed, fed %s" % [placed, game.mech.fed])
	await put_all(extra)
	await shot("windmill-on-the-bastion")
	await leave_build()
	var old_id: int = game.get_instance_id()
	await chat("agostino")
	await settle_scene(old_id)
	check("lift_running", "Agostino throws the switch, and the lift stops appear", flag("port_lift_on") and Data.layout.features.filter(func(f): return f.get("line", "") == "port_lift").size() == 3)
	await ride("port_lift_castle", "port_lift_harbour")
	check("lift_ridden", "down to the harbour in thirty-one seconds", step_done("lift", "ride") and here() == "quay", str(game.player.pos))
	await ride("port_lift_harbour", "port_lift_castle")
	await chat_until("agostino", func(): return done("lift"))
	check("lift_done", "going up?", done("lift"), "%s, %d%%" % [status("lift"), meter()])

func step_nonna() -> void:
	await chat("pina")
	check("nonna_on", "Nonna Pina lends you the metal detector", status("nonna_lire") == "active" and flag(WorldActions.DETECTOR), status("nonna_lire"))
	for nd in Data.layout.nodes.filter(func(x): return x.kind == "dig"):
		await gather_node(String(nd.id))
	check("nonna_tins", "five tins of lire, dug up round town", step_done("nonna_lire", "tins") and inv("port_lire_tin") >= 5, "tins %d" % inv("port_lire_tin"))
	await chat("nicolo")
	check("nonna_changed", "Nicolò counts them out at the bank", step_done("nonna_lire", "change"), Clock.text(game.state.time))
	await chat_until("pina", func(): return done("nonna_lire"))
	check("nonna_done", "a fortune in 1956 notes: thirty-eight euros", done("nonna_lire"), "%s, %d%%" % [status("nonna_lire"), meter()])
	check("baciccia_gives_in", "75%: Baciccia frames his last note, and the fisherman's sweater is yours", meter() >= 75 and game.state.clothes_owned.has("port_sweater"), "%d%%" % meter())

func step_lighthouse() -> void:
	await chat("gerolamo")
	check("light_on", "Gerolamo asks you to light the lighthouse", status("lighthouse") == "active", status("lighthouse"))
	var extra := [["railing", 35, 83, 0, 1.6], ["bench", 33, 84, 0, 1.6], ["lamp", 36, 82, 0, 1.6]]
	var plan := plan_of("lighthouse", 1.6)
	var need := cost_of(plan + extra)
	await buy_until("davide", "port_glass", 4)
	await buy_until("davide", "fabric", int(need.get("fabric", 0)))
	if inv("crystal") < int(need.get("crystal", 0)): await buy_until("davide", "crystal", int(need.crystal))
	await enough_wood(need)
	check("light_materials", "four glass panes, sailcloth and driftwood", step_done("lighthouse", "glass") and step_done("lighthouse", "wood") and step_done("lighthouse", "fabric"), "glass %d" % inv("port_glass"))
	await chat("gerolamo")
	check("light_panes", "Gerolamo takes the panes up to glaze the lantern", step_done("lighthouse", "panes"), str(game.state.quests.get(PP + "lighthouse", {}).get("done", {}).keys()))
	await walk_to(36.0, 80.0, 0.8)
	await open_zone("rock", 0.0)
	var placed := await put_all(plan)
	await frames(30)
	check("light_turning", "a windmill on the rock drives the lighthouse's turning gear", placed == plan.size() and step_done("lighthouse", "turn") and game.mech.fed.get(PP + "lighthouse", false), "%d placed, fed %s" % [placed, game.mech.fed])
	await put_all(extra)
	await shot("windmill-on-the-rock")
	await leave_build()
	if hour() < 20.0 or hour() >= 22.5:
		await sleep_until("bench_quay2", 21)
	var crowd := 0
	for k in 60:
		crowd = game.npcs.values().filter(func(a): return a.def.get("island", "") == "port" and String(a.goal).begins_with("port_bw_") and Vector2(a.pos.x - 40.0, a.pos.z - 68.0).length() < 8.0).size()
		if crowd >= 4: break
		await wait(1.0)
	check("light_crowd", "the town gathers on the breakwater at dusk", crowd >= 4, "%d on the breakwater" % crowd)
	await chat("gerolamo")
	check("light_lit", "after dark you light her with Gerolamo", step_done("lighthouse", "night") and flag("port_finale_night"), Clock.text(game.state.time))
	await chat("rosetta")
	check("light_lire", "the last lire are spent at Rosetta's, open all night", step_done("lighthouse", "lire"), Clock.text(game.state.time))
	await shot("rosettas-at-midnight")
	await chat_until("gerolamo", func(): return done("lighthouse"))
	check("light_done", "the lighthouse is lit", done("lighthouse") and flag("port_lighthouse_lit"), status("lighthouse"))

func finale_checks() -> void:
	await frames(20)
	check("changeover_complete", "everything done: 100% of the changeover", meter() == 100 and game.hud.harmony_label.text == "100%", "%d%%, HUD %s" % [meter(), game.hud.harmony_label.text])
	check("last_lira", "the last lira: euros only, in every place", flag("port_euro_only") and Money.mode() == "euro" and Money.mode_for(game.state.flags, "hearthglow") == "euro" and not wallet().contains("lire"),
		"wallet %s" % wallet())
	check("framed_note", "a framed 1,000-lire note for your wall", inv("port_last_note") == 1)
	var all := Data.quests.filter(func(q): return Data.quest_island(q.id) == "port")
	check("every_request", "every one of Tonnarella's 15 requests is done", all.all(func(q): return String(game.state.quests.get(q.id, {}).get("status", "")) == "done"),
		str(all.filter(func(q): return String(game.state.quests.get(q.id, {}).get("status", "")) != "done").map(func(q): return q.id)))
	await look(PI, 0.3, 30.0)
	await shot("the-bay-at-night")
