extends "full_base.gd"

const OV := preload("../scripts/locations/olive_village.gd")
const PLACES := ["hearthglow", "river_town", "rice_village", "metropolis", "port", "cliffs"]
const P := "olive_village_"
const SECTIONS := ["welcome", "jetty", "water", "terrace", "roof", "sunset", "steps", "swarm", "lost", "festa"]
const SELLER := {"wood": "giobatta", "stone": "giobatta", "metal": "giobatta", "crystal": "giobatta", "clay": "giobatta", "fabric": "giacomo"}
const LOST := {"cap": "giobatta", "guidebook": "hannelore", "glove": "bastian", "binoculars": "marisa", "key": "gina", "radio": "giacomo", "postcard": "delia", "tinboat": "rosa"}

func at(x: float, z: float, tol: float = 1.6) -> bool:
	return Vector2(game.player.pos.x - x, game.player.pos.z - z).length() < tol

func spot(id: String) -> Array:
	return Data.layout.nav_nodes[id]

func go(id: String) -> bool:
	var p := spot(id)
	await walk_to(p[0], p[1], 0.8)
	return at(p[0], p[1])

func building(id: String) -> Dictionary:
	return Data.layout.buildings.filter(func(b): return b.id == id)[0]

func inside(id: String) -> bool:
	var b := building(id)
	var o: Node3D = game.village.objects[id]
	var room := Interiors.room(b, o.position.y)
	return room.has_point(Vector3(game.player.pos.x, room.position.y + 1.0, game.player.pos.z))

func enter(id: String, name: String) -> bool:
	var sp: Array = Data.layout.nav_nodes.get(id + ":spot", [])
	if sp.is_empty(): return false
	await walk_to(sp[0], sp[1], 0.7)
	await wait(1.0)
	await shot(name)
	return inside(id) and float(game.roof_fade.get(id, 1.0)) < 0.2

func play() -> void:
	if not game.shot_cfg.has("from"): await arrive_as_if_played(PLACES)
	var part := String(game.shot_cfg.get("part", ""))
	if part == "shots": await shots(); return
	if part != "requests": await walk_around()
	if part != "walk": await requests()

func walk_around() -> void:
	var s: Dictionary = game.state
	var sp: Dictionary = Data.layout.spawn
	var finales := ["dock", "river_town_levee", "rice_village_train", "metropolis_angel"]
	var done := finales.all(func(q): return s.quests.get(q, {}).get("status", "") == "done")
	check("o1", "you arrive on the pebbles of the cove, with the earlier places' stories done", Data.island == "olive_village" and at(sp.x, sp.z, 2.5) and done, "at (%.1f, %.1f)" % [game.player.pos.x, game.player.pos.z])
	check("o2", "the clock doesn't hold at dusk here, and the sign reads 38", not WorkDay.holds(Data.island_def("olive_village").get("day", {})) and LocationMeter.reading(LocationMeter.def("olive_village"), LocationMeter.points(s, "olive_village")) == "38 inhabitants")
	await shot("cove")
	check("o3", "up the cart track's hairpins to the bridge", await go("bridgeE"))
	await shot("bridge_east")
	var peak := -INF
	var p := spot("bridgeW")
	var budget := 0
	key(KEY_SHIFT, true)
	while not at(p[0], p[1], 0.8) and budget < 400:
		steer(p[0], p[1])
		key(KEY_W, true)
		await frames(1)
		peak = maxf(peak, game.player.pos.y)
		budget += 1
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	check("o4", "over the hump-backed bridge into the village", at(p[0], p[1], 1.0) and peak > OV.BRIDGE_PEAK - 0.3, "highest %.2f m" % peak)
	await shot("bridge_west")
	check("o5", "up the alley past the wash-house to the piazza", await go("piazza"))
	await shot("piazza")
	check("r1", "into Rosa's osteria: the counter, the card tables, the roof fades away", await enter("olive_village_osteria", "osteria"))
	check("r2", "into the barber shop, which is also the town hall", await enter("olive_village_barber", "barber"))
	check("r3", "into the church: pews and the altar", await enter("olive_village_church", "church"))
	check("o6", "out of the church and on up to the castle on top", await go("churchDoor") and await go("castle"))
	await shot("castle")
	check("r4", "down to the Sandals' spotless house, next to your plot", await enter("olive_village_sandals", "sandals"))
	check("o7", "back over the bridge and along the lane to Bastian's farmhouse", await go("bastian"))
	check("r5", "into Bastian's farmhouse", await enter("olive_village_farmhouse", "farmhouse"))
	check("o8", "up the rubble where the fallen terrace's wall came down", await go("fallenFoot") and await go("fallenTop"))
	check("o9", "up the terrace path to the broom terrace and Fuco's hut", await go("hives") and await go("fuco"))
	await shot("terraces")
	check("o10", "down the ramp to the shelf by the torrent, below the bridge", await go("millShelf") and absf(game.player.pos.y - OV.SHELF_H) < 0.1, "at %.2f m" % game.player.pos.y)
	check("o11", "down to the lower mule track", await go("mule1"))
	var top := spot("mule2")
	await walk_direct(top[0], top[1], 0.8, 12.0)
	check("o12", "the collapsed flight of the mule track can't be climbed", not at(top[0], top[1], 1.5), "stopped at (%.1f, %.1f)" % [game.player.pos.x, game.player.pos.z])
	check("r6", "into Gambero's boathouse at the cove", await enter("olive_village_boathouse", "boathouse"))
	check("o13", "back down to the beach", await go("beach"))
	await walk_direct(23.0, 75.0, 0.8, 8.0)
	check("o14", "the sea stops you at the water's edge", game.player.pos.z < OV.shore(game.player.pos.x) + 0.5 and not Heightfield.is_water(game.player.pos.x, game.player.pos.z), "at z %.1f" % game.player.pos.z)
	await shot("sea")

func qs(id: String) -> String: return String(game.state.quests.get(P + id, {}).get("status", ""))
func stage(id: String) -> int: return game.story.engine.current_stage(P + id)
func pts() -> int: return LocationMeter.points(game.state, "olive_village")
func reading() -> String: return LocationMeter.reading(LocationMeter.def("olive_village"), pts())
func flag(f: String) -> bool: return game.state.flags.get(P + f, false)
func hour() -> float: return float(game.state.time.minute) / 60.0
func sign_text() -> String:
	for f in Data.layout.features:
		if f.id == P + "sign": return String(f.text)
	return ""

func expected_pts() -> int:
	var total := 0
	for q in Data.quests:
		if String(q.id).begins_with(P) and qs(String(q.id).trim_prefix(P)) == "done": total += int(q.rewards.get("meter", 0))
	return total

func step_of(id: String, step: String) -> Dictionary:
	for o in Data.quest(P + id).objectives:
		if String(o.id) == step: return o
	return {}

func musts_met(id: String, step: String) -> bool:
	game.story.engine.invalidate()
	var r: Dictionary = game.story.engine.commission(P + id, step_of(id, step))
	return r.musts.all(func(m): return m.ok)

func musts_text(id: String, step: String) -> String:
	game.story.engine.invalidate()
	var r: Dictionary = game.story.engine.commission(P + id, step_of(id, step))
	return ", ".join(r.musts.map(func(m): return "%s %s" % [m.label, "ok" if m.ok else "no"]))

var _game_id := 0
func talk(id: String, accept: bool = true) -> bool:
	_game_id = game.get_instance_id()
	for attempt in 6:
		var a = game.npcs[id]
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[id]
		if not await face_and_press("npc:" + id, a.pos.x, a.pos.z): continue
		for n in 20:
			if game.mode == "dialogue": break
			await frames(2)
		if game.mode == "dialogue": break
		note("pressed E at %s, no dialogue yet (mode %s)" % [id, game.mode])
	if game.mode != "dialogue": print("   no dialogue with ", id); note("no dialogue with %s" % id); return false
	note("talking to %s" % id)
	for n in 300:
		await frames(4)
		if not is_instance_valid(game) or game.mode != "dialogue": return true
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

func settle_world() -> bool:
	if not is_instance_valid(game):
		return await await_rebuild()
	if Data.world_flags == Data.world_flags_of(Data.island, game.state.flags): return true
	return await await_rebuild()

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
	if game.panels.current != "shop": note("%s's shop didn't open (panel '%s')" % [id, game.panels.current])
	return game.panels.current == "shop"

func buy(id: String, item: String, n: int) -> bool:
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

func sell(id: String, item: String) -> bool:
	if not await open_shop(id): return false
	var tab := game.panels.find_child("tab_sell", true, false) as Button
	if tab: await click(tab.get_global_rect().get_center()); await frames(8)
	var b := game.panels.find_child("sell_%s_all" % item, true, false) as Button
	if b == null: b = game.panels.find_child("sell_%s_1" % item, true, false) as Button
	var ok := b != null
	if b: await click(b.get_global_rect().get_center()); await frames(6)
	await tap(KEY_ESCAPE); await frames(8)
	return ok

func bundle(seller: String, item: String) -> int:
	for e in Shop.stock(game.state, P + seller):
		if e.get("kind", "") == "items" and e.items.has(item): return int(e.items[item])
	return 0

func top_up(item: String, n: int) -> bool:
	var seller := String(SELLER.get(item, ""))
	for tries in 6:
		if inv(item) >= n: return true
		var per := bundle(seller, item)
		if per <= 0: break
		var times := ceili(float(n - inv(item)) / per)
		note("buying %d x %d %s from %s for %d" % [times, per, item, seller, n])
		if not await buy(seller, item, times): break
	return inv(item) >= n

func nap_until(h: int) -> bool:
	var p: Vector3 = game.player.pos
	var best := {}
	for f in Data.layout.features:
		if f.kind in ["bench", "rest"] and (best.is_empty() or Vector2(f.x - p.x, f.z - p.z).length() < Vector2(best.x - p.x, best.z - p.z).length()): best = f
	await walk_to(best.x, best.z, 1.1)
	return await sleep_at(best.id, h)

func next_wake(gap: float) -> int:
	for w in [6, 9, 12, 18, 21]:
		if fposmod(w - hour(), 24.0) >= gap: return w
	return 6

func wait_until(h: float, max_s: float = 3600.0) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		var now := hour()
		if now >= h and now < h + 1.0: return
		await wait(1.0)

func daytime() -> void:
	if hour() < 7.0 or hour() >= 20.0: await nap_until(9)

func pick_up(node: String) -> bool:
	var n := Data.node_def(node)
	if game.state.nodes.get(node, {}).get("done", false): note("%s was already picked up" % node); return true
	var have: int = inv(n.gives.keys()[0])
	await walk_to(n.x, n.z, 0.5)
	await walk_direct(n.x, n.z, 0.35, 6.0)
	await frames(20)
	return inv(n.gives.keys()[0]) > have

func gather_more(kind: String, test: Callable, only: Array = [], rounds: int = 30) -> bool:
	var unreachable := {}
	for r in rounds:
		if test.call(): return true
		var p: Vector3 = game.player.pos
		var ready: Array = Data.layout.nodes.filter(func(n): return n.kind == kind and (only.is_empty() or only.has(n.id)) and game.actions.ready(n) and not unreachable.has(n.id))
		if ready.is_empty():
			var waiting: bool = Data.layout.nodes.any(func(n): return n.kind == kind and (only.is_empty() or only.has(n.id)) and not unreachable.has(n.id))
			if not waiting: note("no %s left that can be reached" % kind); break
			note("nothing to %s has grown back: nap" % kind); await nap_until(next_wake(4.0)); continue
		ready.sort_custom(func(a, b): return Vector2(a.x - p.x, a.z - p.z).length() < Vector2(b.x - p.x, b.z - p.z).length())
		note("gather %s (%d) wood=%d stone=%d flowers=%d" % [ready[0].id, r, inv("wood"), inv("stone"), inv("flowers")])
		if not await gather_node(ready[0].id): unreachable[ready[0].id] = true; note("could not reach %s" % ready[0].id)
	return test.call()

func plain(kind: String) -> Array:
	return Data.layout.nodes.filter(func(n): return n.kind == kind and not n.has("gives") and not n.has("flag")).map(func(n): return n.id)

func chop_some(n: int) -> bool:
	var before := inv("wood")
	return await gather_more("chop", func(): return inv("wood") >= before + n, plain("chop"), 12)

func quarry_some(n: int) -> bool:
	var before := inv("stone")
	return await gather_more("mine", func(): return inv("stone") >= before + n, plain("mine"), 12)

func turn_view(angle: float) -> void:
	var mid: Vector2 = game.get_viewport().get_visible_rect().size / 2.0
	var px := angle / (0.0055 * float(game.settings.sensitivity))
	var steps := maxi(1, int(ceil(absf(px) / 20.0)))
	mouse_button(mid, MOUSE_BUTTON_RIGHT, true); await frames(1)
	for s in steps:
		mouse_move(mid, Vector2(px / steps, 0)); await frames(1)
	mouse_button(mid, MOUSE_BUTTON_RIGHT, false); await frames(2)

func aims_for(id: String, i: float, k: float, r: int, y: float) -> Array:
	var fp := BuildGrid.footprint(Data.piece(id), r)
	var c := Vector3(i + fp.x / 2.0, y + 0.02, k + fp.y / 2.0)
	var out: Array = [c]
	for off in [Vector2(-0.4, -0.4), Vector2(0.4, 0.4), Vector2(-0.4, 0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0, -0.4), Vector2(0, 0.4)]:
		out.append(c + Vector3(off.x, 0, off.y))
	if fp.x > 1.0 or fp.y > 1.0:
		for dy in [0.1, 0.25]:
			for t in [0.35, 0.5, 0.65]:
				out.append(Vector3(i + fp.x * t, y - dy, k + 0.2))
				out.append(Vector3(i + fp.x * t, y - dy, k + fp.y - 0.2))
				out.append(Vector3(i + 0.2, y - dy, k + fp.y * t))
				out.append(Vector3(i + fp.x - 0.2, y - dy, k + fp.y * t))
	return out

func put(id: String, i: float, k: float, r: int, y: float) -> bool:
	if game.build.item_id != id: await select_piece(id)
	for n in 12:
		if game.build.rotation == r: break
		await tap(KEY_R); await frames(2)
	var aims := aims_for(id, i, k, r, y)
	game.build.focus = Vector3(aims[0].x, y, aims[0].z)
	var p := Vector2.ZERO
	var on_it := false
	var pitch: float = game.cam.pitch
	for v in 6:
		if v == 1 or v >= 3: await turn_view(PI / 2.0)
		if v == 2: game.cam.pitch = 1.35
		for aim in aims:
			await settle()
			p = game.camera.unproject_position(aim)
			mouse_move(p, Vector2(1, 0)); await frames(4)
			var cand: Dictionary = game.build.check.get("pl", {})
			if not cand.is_empty() and cand.id == id and is_equal_approx(float(cand.i), i) and is_equal_approx(float(cand.k), k) and int(cand.r) == r and absf(float(cand.y) - y) < 0.25: on_it = true; break
			await frames(2)
		if on_it: break
	if not on_it:
		game.cam.pitch = pitch
		note("could not point at %d,%d (y %.2f) for %s: the cursor is on %s" % [i, k, y, id, game.build.check.get("pl", {})])
		return false
	var status_text: String = game.build.status_label.text if game.build.status_label else ""
	var before: int = game.state.placements.size()
	mouse_button(p, MOUSE_BUTTON_LEFT, true); mouse_button(p, MOUSE_BUTTON_LEFT, false)
	await frames(3)
	var ok: bool = game.state.placements.size() > before and game.state.placements.back().id == id and is_equal_approx(float(game.state.placements.back().i), i) and is_equal_approx(float(game.state.placements.back().k), k)
	game.cam.pitch = pitch
	if not ok: note("could not place %s at %d,%d (y %.2f): %s" % [id, i, k, y, status_text])
	return ok

func build_plan(id: String, step: String) -> bool:
	var o := step_of(id, step)
	var zone := Data.zone(String(o.zone))
	for round in 3:
		var missing := 0
		for pl in Plans.lay_out(o.plan, zone, []):
			if Plans.built(pl, game.state.placements) and game.state.placements.filter(func(q): return q.id == pl.id and is_equal_approx(float(q.i), float(pl.i)) and is_equal_approx(float(q.k), float(pl.k)) and absf(float(q.y) - float(pl.y)) < 0.05).size() > 0: continue
			if not await put(String(pl.id), float(pl.i), float(pl.k), int(pl.r), float(pl.y)): missing += 1
		note("%s/%s: round %d, %d pieces not placed" % [id, step, round, missing])
		if missing == 0: return true
		await turn_view(PI / 3.0)
	return false

func requests() -> void:
	var from := String(game.shot_cfg.get("from", "welcome"))
	var k0 := SECTIONS.find(from)
	if k0 > 0:
		var saved: Dictionary = SaveSystem.read("ov_" + SECTIONS[k0 - 1])
		if saved.is_empty(): check("from", "A checkpoint to start from", false, "no ov_%s" % SECTIONS[k0 - 1]); return
		game.load_state(saved)
		await await_rebuild(20.0)
		await frames(20)
	else:
		note("requests: day %d %s, coins %d" % [int(game.state.time.day), Clock.text(game.state.time), Shop.coins(game.state)])
		await daytime()
	var k1 := SECTIONS.find(String(game.shot_cfg.get("to", "festa")))
	for k in range(maxi(k0, 0), (k1 if k1 >= 0 else SECTIONS.size() - 1) + 1):
		note("section %s: day %d %s, coins %d" % [SECTIONS[k], int(game.state.time.day), Clock.text(game.state.time), Shop.coins(game.state)])
		await call("sec_" + SECTIONS[k])
		SaveSystem.write("ov_" + SECTIONS[k], game.snapshot())

func sec_welcome() -> void:
	await talk(P + "giobatta")
	var accepted: bool = qs("welcome") == "active" and flag("tour")
	await talk(P + "giacomo")
	var thanked: bool = stage("welcome") >= 1
	var chopped := await chop_some(1)
	await gather_more("chop", func(): return inv("wood") >= 3, plain("chop"), 8)
	var quarried := await quarry_some(1)
	await gather_more("mine", func(): return inv("stone") >= 3, plain("mine"), 8)
	await talk(P + "klaus")
	await daytime()
	await talk(P + "giobatta")
	await settle_world()
	var signed: bool = stage("welcome") >= 4 or qs("welcome") == "done"
	if qs("welcome") != "done":
		await talk(P + "giobatta")
		await settle_world()
	await shot("welcome-done")
	check("s1", "Welcome to Liolivato: the Sindaco on the pebbles, Gambero thanked, chestnut wood and terrace stone, the Sandals next door, the house signed for in the barber's chair, and the sign reads 39",
		accepted and thanked and chopped and quarried and signed and qs("welcome") == "done" and pts() == 1 and reading() == "39 inhabitants" and sign_text() == "Liolivato. 39 inhabitants.",
		"accepted=%s thanked=%s chopped=%s quarried=%s signed=%s %s, %s, sign '%s'" % [accepted, thanked, chopped, quarried, signed, qs("welcome"), reading(), sign_text()])

func sec_jetty() -> void:
	await daytime()
	await talk(P + "marisa")
	var acc: bool = qs("jetty") == "active" and game.state.blueprints.has("pontoon") and inv("clay") >= 7
	await chop_some(2)
	await top_up("wood", 21)
	await top_up("metal", 1)
	await top_up("crystal", 1)
	await walk_to(24.5, 57.5, 0.8)
	await open_build(P + "jetty")
	var placed := await build_plan("jetty", "build")
	var musts := musts_met("jetty", "build")
	var detail := musts_text("jetty", "build")
	await shot("jetty-built")
	await leave_build()
	await walk_to(24.5, 58.6, 0.5)
	await walk_direct(24.5, 60.4, 0.35, 10.0)
	await walk_direct(24.5, 71.8, 0.4, 40.0)
	var walked: bool = game.player.pos.z > 71.0 and game.player.pos.y > -0.3
	var end_at: Vector3 = game.player.pos
	await shot("jetty-end")
	await talk(P + "marisa")
	await settle_world()
	await shot("ferry-moored")
	check("s2", "The Jetty: Sirena's caulking clay, chestnut wood and metal, pontoons out from the pebbles with a lantern, you walk to the end, the ferry ties up and the sign reads 40",
		acc and placed and musts and walked and qs("jetty") == "done" and pts() == expected_pts() and reading() == "40 inhabitants" and flag("plot") and Data.world_flags.has(P + "jetty_done"),
		"acc=%s placed=%s musts=[%s] walked=%s (end %s) %s, %s" % [acc, placed, detail, walked, end_at, qs("jetty"), reading()])

func sec_water() -> void:
	await daytime()
	await talk(P + "bastian")
	var acc: bool = qs("water") == "active" and inv("clay") >= 12
	await top_up("metal", 2)
	await top_up("clay", 15)
	await chop_some(1)
	await top_up("wood", 5)
	await walk_to(12.0, 24.0, 0.8)
	await open_build(P + "works")
	var placed := await build_plan("water", "build")
	var fed: bool = game.mech.fed.get(P + "tank", false)
	await shot("waterwheel")
	await leave_build()
	await talk(P + "bastian")
	await settle_world()
	await walk_to(13.0, 38.4, 0.8)
	await shot("tank-full")
	check("s3", "Water for the Terraces: a waterwheel in the torrent below the bridge, a pump on the shelf, pipes up the ramp, the tank fills and the sign reads 41",
		acc and placed and fed and qs("water") == "done" and pts() == expected_pts() and reading() == "41 inhabitants" and Data.world_flags.has(P + "water_done"),
		"acc=%s placed=%s fed=%s %s, %s" % [acc, placed, fed, qs("water"), reading()])

func sec_terrace() -> void:
	await daytime()
	await talk(P + "bastian")
	var acc: bool = qs("terrace") == "active" and game.state.blueprints.has("stoneBlock")
	var quarried := await quarry_some(2)
	await top_up("stone", 24)
	await top_up("wood", 2)
	await walk_to(40.0, -10.4, 0.8)
	await open_build(P + "wall")
	var placed := await build_plan("terrace", "build")
	var musts := musts_met("terrace", "build")
	var detail := musts_text("terrace", "build")
	await shot("terrace-wall")
	await leave_build()
	await talk(P + "bastian")
	await settle_world()
	check("s4", "The Fallen Terrace: stone from the rubble, the wall rebuilt with no gap, steps up onto it, and the sign reads 42",
		acc and quarried and placed and musts and qs("terrace") == "done" and pts() == expected_pts() and reading() == "42 inhabitants",
		"acc=%s quarried=%s placed=%s musts=[%s] %s, %s" % [acc, quarried, placed, detail, qs("terrace"), reading()])

func sec_roof() -> void:
	await daytime()
	await talk(P + "giobatta")
	var acc: bool = qs("roof") == "active" and game.state.blueprints.has("roof")
	await chop_some(2)
	await top_up("wood", 28)
	await top_up("clay", 1)
	await top_up("fabric", 2)
	await gather_more("flowers", func(): return inv("flowers") >= 4, plain("flowers"), 10)
	var coins_ok: bool = Shop.coins(game.state) >= 120
	await go("yourHouse")
	await open_build(P + "house")
	var placed := await build_plan("roof", "house")
	var musts := musts_met("roof", "house")
	var detail := musts_text("roof", "house")
	await shot("your-house")
	await leave_build()
	await talk(P + "giobatta")
	await settle_world()
	check("s5", "A Roof for 1,000 Lire: walls, a door, a roof on top and a bed bought from your savings; the sign reads 43, with the beehive plans and a bigger terrace",
		acc and coins_ok and placed and musts and qs("roof") == "done" and pts() == expected_pts() and reading() == "43 inhabitants" and flag("hive_plans") and game.state.blueprints.has("beehive"),
		"acc=%s coins=%s placed=%s musts=[%s] %s, %s" % [acc, coins_ok, placed, detail, qs("roof"), reading()])

func sec_sunset() -> void:
	await daytime()
	await talk(P + "klaus")
	var acc: bool = qs("sunset") == "active" and game.state.blueprints.has("pillar")
	await top_up("wood", 5)
	await top_up("stone", 4)
	await top_up("clay", 1)
	await go("yourHouse")
	await open_build(P + "sunset")
	var placed := await build_plan("sunset", "build")
	var musts := musts_met("sunset", "build")
	var detail := musts_text("sunset", "build")
	await shot("sunset-seat")
	await leave_build()
	await talk(P + "klaus")
	await settle_world()
	check("s6", "The Sandals' Sunset: pillars, a roof and a bench on their terrace, with the sea in view from the seat",
		acc and placed and musts and qs("sunset") == "done" and pts() == expected_pts() and reading() == "44 inhabitants",
		"acc=%s placed=%s musts=[%s] %s, %s" % [acc, placed, detail, qs("sunset"), reading()])

func sec_steps() -> void:
	await daytime()
	await talk(P + "giacomo")
	var acc: bool = qs("steps") == "active"
	await quarry_some(1)
	await top_up("stone", 12)
	await go("mule1")
	await open_build(P + "steps")
	var placed := await build_plan("steps", "build")
	var musts := musts_met("steps", "build")
	await shot("gamberos-steps")
	await leave_build()
	await go("mule1")
	var top := spot("mule2")
	await walk_direct(20.2, 34.2, 0.4, 10.0)
	await walk_direct(top[0], top[1], 0.8, 20.0)
	var climbed := at(top[0], top[1], 1.2)
	await talk(P + "giacomo")
	await settle_world()
	var by_steps: bool = Schedule.find_path("mule1", "mule2", game.state.flags) == ["mule1", "mule2"]
	check("s7", "Gambero's Steps: stone blocks rebuild the collapsed flight, you walk all the way up the mule track, and Gambero takes the short way again",
		acc and placed and musts and climbed and by_steps and qs("steps") == "done" and pts() == expected_pts() and reading() == "45 inhabitants",
		"acc=%s placed=%s musts=%s climbed=%s (at %s) by_steps=%s %s, %s" % [acc, placed, musts, climbed, game.player.pos, by_steps, qs("steps"), reading()])

func sec_swarm() -> void:
	await daytime()
	await talk(P + "ilario")
	var acc: bool = qs("swarm") == "active"
	await chop_some(1)
	await top_up("wood", 7)
	await gather_more("flowers", func(): return inv("flowers") >= 2, plain("flowers"), 10)
	await go("hives")
	await open_build(P + "hives")
	var placed := await build_plan("swarm", "build")
	var musts := musts_met("swarm", "build")
	await shot("hives")
	await leave_build()
	await talk(P + "ilario")
	var box: bool = flag("swarm_ready")
	if hour() < 5.0 or hour() >= 8.0: await nap_until(6)
	await gather_node(P + "swarm")
	var caught: bool = inv(P + "swarm") >= 1
	var dawn: bool = hour() >= 5.0 and hour() < 9.0
	await shot("swarm-in-a-box")
	await talk(P + "ilario")
	await talk(P + "giobatta")
	await settle_world()
	check("s8", "Fuco's Swarm: three hives with flowers on the broom terrace, the box on a pole, the swarm coaxed down from the bell tower at dawn, and the bells ring again",
		acc and placed and musts and box and caught and dawn and qs("swarm") == "done" and pts() == expected_pts() and reading() == "46 inhabitants" and flag("own_olive") and Data.world_flags.has(P + "own_olive"),
		"acc=%s placed=%s musts=%s box=%s caught=%s at %.1f h %s, %s, own olive %s" % [acc, placed, musts, box, caught, hour(), qs("swarm"), reading(), flag("own_olive")])

func sec_lost() -> void:
	await daytime()
	var before := pts()
	for key in LOST:
		if qs("lost_" + key) == "": await talk(P + String(LOST[key]))
	var asked: bool = LOST.keys().all(func(k): return qs("lost_" + k) == "active" or qs("lost_" + k) == "done")
	var found := 0
	for key in LOST:
		await daytime()
		if await pick_up(P + "lost_" + key): found += 1
	await shot("lost-things")
	for key in LOST:
		await daytime()
		if qs("lost_" + key) != "done": await talk(P + String(LOST[key]))
		if qs("lost_" + key) != "done": await talk(P + String(LOST[key]))
	var all_done: bool = LOST.keys().all(func(k): return qs("lost_" + k) == "done")
	check("l1", "Eight lost things: asked about, found under the brambles and along the shore, and given back, without changing the sign",
		asked and found == LOST.size() and all_done and pts() == before, "asked=%s found=%d done=%s sign %s" % [asked, found, all_done, reading()])

func sec_festa() -> void:
	await daytime()
	if qs("festa") == "": await talk(P + "giobatta")
	var acc: bool = qs("festa") == "active" and game.state.blueprints.has("petalCarpet")
	if not game.story.engine.objective(P + "festa", step_of("festa", "rosa")).done: await talk(P + "rosa")
	var favour: bool = game.story.engine.objective(P + "festa", step_of("festa", "rosa")).done
	await gather_more("flowers", func(): return inv("flowers") >= 26, plain("flowers"), 30)
	await chop_some(2)
	await top_up("wood", 19)
	await top_up("fabric", 4)
	await top_up("crystal", 3)
	await daytime()
	await go(P + "empty_house:spot")
	await open_build(P + "davide")
	var room := await build_plan("festa", "room")
	await shot("the-empty-house-ready")
	await leave_build()
	await go("bridgeW")
	await open_build(P + "carpet")
	var carpet := await build_plan("festa", "carpet")
	var carpet_ok := musts_met("festa", "carpet")
	await shot("petal-carpet")
	await leave_build()
	await go("piazzaS")
	await open_build(P + "piazza")
	var tables := await build_plan("festa", "piazza")
	await shot("piazza-set")
	await leave_build()
	var ready: bool = flag("festa_ready")
	if hour() < 18.0 and hour() >= 6.0: await nap_until(18)
	await wait_until(20.0)
	await talk(P + "giobatta")
	var night: bool = flag("festa_night")
	await settle_world()
	await go("piazza")
	await shot("festa-night")
	await talk(P + "davide")
	await settle_world()
	await shot("fifty")
	check("s9", "The Festa: Rosa's quiet favour (beds, a table and a lamp in the empty house), a petal carpet from the bridge to the piazza, tables, seats and lights, and the band's evening",
		acc and favour and room and carpet and carpet_ok and tables and ready and night, "acc=%s favour=%s room=%s carpet=%s/%s tables=%s ready=%s night=%s" % [acc, favour, room, carpet, carpet_ok, tables, ready, night])
	check("s10", "Davide's family walks up behind the band, Rosa's son is home, and the Sindaco repaints the sign: 50",
		qs("festa") == "done" and pts() == 12 and reading() == "50 inhabitants" and sign_text() == "Liolivato. 50 inhabitants." and flag("free_haircut") and Data.world_flags.has(P + "festa_night"),
		"%s, %s, sign '%s', haircut %s" % [qs("festa"), reading(), sign_text(), flag("free_haircut")])

func view(x: float, z: float, yaw: float, pitch: float, dist: float, h: float, name: String) -> void:
	game.state.time.minute = h * 60.0
	game.player.teleport(x, z)
	for a in game.npcs.values(): a.teleport_home()
	game.cam.yaw = yaw; game.cam.pitch = pitch; game.cam.dist = dist
	game.cam.limits.explore = [2.0, 120.0, 0.05, 1.5]
	game.cam.update(0.016, game.player.pos); game.cam.snap()
	await wait(2.5)
	await shot(name)

func story_at(flags: Array) -> void:
	for f in flags: game.state.flags[P + f] = true
	var built: Array = game.state.placements
	for q in Data.quests.filter(func(x): return Data.quest_island(String(x.id)) == "olive_village"):
		for o in q.objectives:
			if not o.has("plan"): continue
			for pl in Plans.lay_out(o.plan, Data.zone(String(o.zone)), built):
				pl.uid = int(game.state.next_uid)
				game.state.next_uid = int(game.state.next_uid) + 1
				built.append(pl)
	game.request_rebuild()
	await await_rebuild()

func shots() -> void:
	game.shot_cfg["weather"] = "clear"
	await view(-20.0, 0.0, 0.0, 0.45, 16.0, 21.5, "festa-before")
	await story_at(["welcomed", "jetty_done", "water_done", "terrace_done", "roof_done", "sunset_done", "swarm_done", "steps_done", "own_olive", "festa_ready", "festa_night", "festa_done"])
	await view(-3.5, 16.5, 0.15, 0.3, 5.0, 11.0, "sign-fifty")
	await view(24.5, 58.0, PI, 0.55, 20.0, 10.0, "ferry-at-the-jetty")
	await view(12.5, 35.5, -2.68, 0.6, 9.0, 11.0, "tank-full")
	await view(-20.0, 0.0, 0.0, 0.45, 16.0, 21.5, "festa-night")
	await view(-6.0, 6.0, 0.6, 1.0, 26.0, 17.0, "petal-carpet")
	await view(-21.0, 17.5, 0.0, 0.5, 13.0, 16.0, "your-house-and-the-sandals-seat")
	await view(-18.6, 18.5, PI, 0.35, 7.0, 17.0, "your-olive-tree")
	await view(52.0, -52.5, 0.0, 0.5, 12.0, 11.0, "hives")
	await view(20.0, 37.0, 0.0, 0.6, 12.0, 11.0, "gamberos-steps")
	await view(40.0, -10.5, 0.0, 0.55, 14.0, 11.0, "terrace-wall")
