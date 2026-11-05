extends "res://tests/full_base.gd"
## Casalrana's requests with real input, part one: Welcome to Casalrana, The Flat above the Station (up the outside
## stair, patching the roof, furnishing the flat in build mode, sleeping in your own bed), Water for the Winter (the
## sluice and the waterwheel, pump and pipes to the winter paddy), Nonna's Bench (and the song at dusk), Things from the
## Trains and Matteo's Museum. Then it saves to slot 2 for part two (play_rice_village3.gd).
## It starts as if you had played Monteforchetta's and Boccapioppo's main stories and come on the bus (arrive_as_if_played).
## Run: TIMEOUT=7100 ./play.sh res://tests/play_rice_village2.gd /tmp/out --island=rice_village --limit=7000
##
## The harness reads game state and turns the camera the way a mouse drag would; everything else is key and mouse
## input. Time passes by sleeping on a bed or bench, as a player would.

const P := "rice_village_"

func status(qid: String) -> String: return String(q(P + qid).get("status", ""))
func progress(qid: String, oid: String) -> int: return int(q(P + qid).progress.get(oid, 0))
func signatures() -> int: return LocationMeter.points(game.state, "rice_village")

## Talks to a villager like full_base's talk, but only takes on the request `want` when one is offered in the list
## (a main request they bring up themselves is always accepted, and payments are always made).
func talk_for(id: String, want: String = "") -> bool:
	for attempt in 6:
		var a = game.npcs[id]
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[id]
		if await face_and_press("npc:" + id, a.pos.x, a.pos.z): break
	for n in 20:
		if game.mode == "dialogue": break
		await frames(2)
	if game.mode != "dialogue": note("no dialogue with %s" % id); return false
	for n in 400:
		await frames(4)
		if game.mode != "dialogue": return true
		var ui: DialogueUI = game.dialogue
		if ui.choices.is_empty(): await tap(KEY_E); continue
		var idx := -1
		for i in ui.choices.size():
			var c: Dictionary = ui.choices[i]
			if c.kind == "yes" or c.kind == "pay" or (c.kind == "offer" and (want == "" or c.get("id", "") == want)): idx = i; break
		if idx < 0:
			for i in ui.choices.size():
				if ui.choices[i].kind == "bye": idx = i
		note("   %s > %s" % [id, ui.choices[idx].label])
		await tap(KEY_1 + idx)
	return true

func talk(id: String, accept: bool = true) -> bool: return await talk_for(id, "" if accept else "-")

## Opens build mode at a site (cycling through the open ones).
func open_build(zone_id: String) -> void:
	await tap(KEY_B); await frames(5)
	for i in 16:
		if game.build.current_zone.get("id", "") == zone_id: break
		game.build.cycle_zone(1); await frames(2)
	game.cam.yaw = 0.35; game.cam.pitch = 1.05; game.cam.dist = 15
	await frames(6)

## Waits until the level crossing is open and will stay open for a few minutes.
func safe_to_cross() -> void:
	var tt = load("res://scripts/locations/rice_village/timetable.gd")
	await wait_until(func():
		var d := int(game.state.time.day); var m := float(game.state.time.minute)
		return not tt.crossing_closed(d, m) and not tt.crossing_closed(d, m + 1.5) and not tt.crossing_closed(d, m + 3.0), 120.0)

func to_bench() -> void: await walk_to(15.3, -38.3, 0.5)

## Waits (in game) until cond is true or max_s real seconds pass.
func wait_until(cond: Callable, max_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		if cond.call(): return true
		await frames(4)
	return cond.call()

## Gathers until this request step has counted enough, and you hold at least `keep` of the item.
func gather_for(kind: String, qid: String, oid: String, need: int, item: String, keep: int = 0, rounds: int = 20) -> bool:
	return await gather_until(kind, func(): return progress(qid, oid) >= need and inv(item) >= keep, [], rounds)

## Gathers until you hold n of an item (for building).
func gather_to(kind: String, item: String, n: int, rounds: int = 24) -> bool:
	return await gather_until(kind, func(): return inv(item) >= n, [], rounds)

## Opens a villager's shop from their conversation and buys a line `times` times.
func buy(npc: String, item: String, times: int = 1) -> bool:
	var a = game.npcs[P + npc]
	for attempt in 4:
		await walk_to(a.pos.x, a.pos.z, 1.5)
		if await face_and_press("npc:" + P + npc, a.pos.x, a.pos.z): break
	for n in 300:
		await frames(4)
		if game.mode != "dialogue": continue
		var ui: DialogueUI = game.dialogue
		if ui.choices.is_empty(): await tap(KEY_E); continue
		var i: int = ui.choices.map(func(o): return o.get("kind", "")).find("shop")
		if i < 0: i = ui.choices.map(func(o): return o.get("kind", "")).find("bye")
		await tap(KEY_1 + i)
		break
	for n in 80:
		await frames(4)
		if game.panels.current == "shop": break
		if game.mode == "dialogue" and game.dialogue.choices.is_empty(): await tap(KEY_E)
	if game.panels.current != "shop": note("no shop with %s" % npc); return false
	var lines := Shop.stock(game.state, P + npc)
	var idx := -1
	for j in lines.size():
		if lines[j].get("items", {}).has(item): idx = int(lines[j].i)
	var got := 0
	for t in times:
		await frames(6)
		var b := game.panels.find_child("buy_%d" % idx, true, false) as Button
		if b == null or b.disabled: break
		await click(b.get_global_rect().get_center()); got += 1
	await frames(6)
	await tap(KEY_ESCAPE); await frames(6)
	return got == times

## Loads a save from the title screen, as a player would.
func load_slot(slot: String) -> void:
	await frames(20)
	var title_load: Control = game.screens.find_child("btn_load", true, false)
	if title_load: await click(title_load.get_global_rect().get_center()); await frames(10)
	var l: Control = game.screens.find_child("load_slot" + slot, true, false)
	if l: await click(l.get_global_rect().get_center()); await frames(40)

## Where the cursor lands over a cell: the top of what's built there, the ground or a raised floor, or the water's
## surface where the ground is under water (build mode's own cursor rule).
func surface_at(x: float, z: float) -> float:
	var y := BuildGrid.ground_at(floorf(x), floorf(z))
	if Heightfield.height(x, z) < Heightfield.WATER_Y and y < Heightfield.WATER_Y + 0.01: y = 0.1
	for pl in game.state.placements:
		var b := BuildGrid.bounds(pl)
		if x > b.minX and x < b.maxX and z > b.minZ and z < b.maxZ: y = maxf(y, b.top)
	return y

## Places a list of [piece, i, k, rotation] in a build site, then leaves build mode. Each piece is aimed at the middle
## of its footprint, on the surface the cursor will land on there.
func build(zone: String, pieces: Array) -> Array:
	await open_build(zone)
	var out: Array = []
	for e in pieces:
		if game.build.item_id != e[0]: await select_piece(e[0])
		var before: int = game.state.placements.size()
		var r: int = e[e.size() - 1]
		var fp := BuildGrid.footprint(Data.piece(e[0]), r)
		var cx: float = e[1] + fp.x / 2.0; var cz: float = e[2] + fp.y / 2.0
		var aim := Vector3(cx, surface_at(cx, cz), cz)
		if Data.piece(e[0]).get("needsSupport", false):   # a roof: aim at the top of what holds it up, as a player would
			var bd := INF
			for pl in game.state.placements:
				var b := BuildGrid.bounds(pl)
				if b.maxX <= e[1] or b.minX >= e[1] + fp.x or b.maxZ <= e[2] or b.minZ >= e[2] + fp.y: continue
				var px := clampf(cx, b.minX + 0.05, b.maxX - 0.05); var pz := clampf(cz, b.minZ + 0.05, b.maxZ - 0.05)
				var d := Vector2(px - cx, pz - cz).length()
				if d < bd: bd = d; aim = Vector3(px, b.top, pz)
		var st := await place_at(aim.x - 0.5, aim.z - 0.5, aim.y, r)
		out.append("%s@%d,%d %s" % [e[0], e[1], e[2], "ok" if game.state.placements.size() > before else "refused (%s)" % st])
	await leave_build()
	return out

## Walks (no running) towards a spot, for tight places like the landing and inside the tower: at a couple of frames
## a second a running step is longer than the landing is wide.
func walk_slow(x: float, z: float, tol: float = 0.5, max_s: float = 30.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		var p: Vector3 = game.player.pos
		if Vector2(x - p.x, z - p.z).length() < tol: break
		steer(x, z); key(KEY_W, true); await frames(1); key(KEY_W, false)
	key(KEY_W, false); await frames(2)
	return Vector2(x - game.player.pos.x, z - game.player.pos.z).length() < tol + 0.3

## Up the outside stair at the station's east end and in at the flat's door.
func climb_to_flat() -> bool:
	await walk_to(25.7, -30.6, 0.6)
	await walk_slow(25.7, -37.3, 0.5)
	await walk_slow(22.0, -37.6, 0.6)
	return game.player.pos.y > 3.3

func down_from_flat() -> void:
	await walk_slow(25.7, -37.3, 0.5)
	await walk_slow(25.7, -30.6, 0.6)

func play() -> void:
	check(1, "the game starts in Casalrana", Data.island == "rice_village", Data.island)
	await frames(10)
	# --from=water (with --title) picks up from the save this makes after the flat (slot 1), to rerun the rest
	if String(game.shot_cfg.get("from", "")) == "water":
		await load_slot("1")
		check(3, "resumed from the save after the flat", game.mode == "explore" and status("flat") == "done", "mode %s flat %s" % [game.mode, status("flat")])
	else:
		await arrive_as_if_played(["hearthglow", "river_town"])   # the bus brings you on from Boccapioppo, after Monteforchetta
		check(2, "the HUD shows Paletta's petition instead of the approval rating", game.hud.harmony_title.text.ends_with("The Petition") and game.hud.harmony_label.text == "0", "%s %s" % [game.hud.harmony_title.text, game.hud.harmony_label.text])
		await welcome()
		await flat()
		await save_to("slot1")
	await water()
	await bench()
	await lost_things()
	await museum()
	await shot("end-part-one")
	var saved := await save_to("slot2")
	check(90, "part one saved to slot 2", saved, "signatures %d, day %d" % [signatures(), int(game.state.time.day)])

# ---- Welcome to Casalrana ---------------------------------------------------------------------------------------
func welcome() -> void:
	var pal = game.npcs[P + "ernesto"]
	check(10, "Paletta waits for your bus at the crossroads", Vector2(pal.pos.x - 2.8, pal.pos.z - 0.2).length() < 2.0 and game.story.marker_for(P + "ernesto") == "offer", str(pal.pos))
	await talk(P + "ernesto")
	check(11, "he welcomes you and gives you the Geometra's kit back", status("welcome") == "active" and game.state.flags.get("hasTool", false), status("welcome"))
	await walk_to(2.0, -42.0, 1.0)
	check(12, "walk up the road to the level crossing", progress("welcome", "crossing") >= 1, str(game.player.pos))
	for who in ["battista", "pierina", "remo"]:
		await talk(P + who)
	check(13, "meet Barba Tista, Nonna Pierina and Don Remo", progress("welcome", "tista") == 1 and progress("welcome", "nonna") == 1 and progress("welcome", "remo") == 1,
		"tista %d nonna %d remo %d" % [progress("welcome", "tista"), progress("welcome", "nonna"), progress("welcome", "remo")])
	await gather_for("chop", "welcome", "wood", 3, "wood")
	check(14, "chop wood from the poplars", progress("welcome", "wood") >= 3, "wood %d" % inv("wood"))
	await gather_for("mine", "welcome", "stone", 3, "stone")
	check(15, "quarry stone from the canal's cobbles", progress("welcome", "stone") >= 3, "stone %d" % inv("stone"))
	await talk(P + "ernesto")
	check(16, "Welcome to Casalrana is done: 20 signatures and the keys to the flat", status("welcome") == "done" and signatures() == 20 and game.state.flags.get("rice_village_welcomed", false), "signatures %d" % signatures())

# ---- The Flat above the Station ---------------------------------------------------------------------------------
func flat() -> void:
	await talk(P + "ernesto")
	check(20, "Paletta offers the flat above the station", status("flat") == "active", status("flat"))
	await gather_for("clay", "flat", "clay", 4, "clay", 4, 12)
	await gather_for("chop", "flat", "wood", 10, "wood", 10)
	check(21, "dig clay for tiles and chop wood for battens and furniture", progress("flat", "clay") >= 4 and progress("flat", "wood") >= 10, "clay %d wood %d" % [inv("clay"), inv("wood")])
	var up := await climb_to_flat()
	check(22, "up the outside stair and in at the flat's door", up, str(game.player.pos))
	await shot("flat-before")
	if not await face_and_press("rice_village_roof", 19.0, -38.0): note("no roof prompt (target %s)" % (game.target.id if game.target else "none"))
	await frames(20)
	check(23, "patch the leaking roof from inside the flat", progress("flat", "roof") == 1 and game.state.flags.get("rice_village_roofPatched", false), "roof %d" % progress("flat", "roof"))
	await down_from_flat()
	await gather_to("chop", "wood", 7)
	await climb_to_flat()
	var placed := await build(P + "flat", [["bed", 14, -40, 0], ["table", 17, -39, 0], ["chair", 17, -38, 2], ["lamp", 20, -40, 0]])
	note("flat: %s" % [placed])
	await frames(10)
	await shot("flat-furnished")
	check(24, "furnish the flat in build mode: a bed, a table, a chair and a lamp on its floor", progress("flat", "furnish") == 1 and game.state.placements.all(func(p): return absf(p.y - 3.5) < 0.05), str(placed))
	check(25, "the flat's roof fades while you're in it, the waiting room's doesn't", game.roof_fade.get(P + "flat", 1.0) < 0.05 and game.roof_fade.get(P + "station", 0.0) > 0.95,
		"flat %.2f station %.2f" % [game.roof_fade.get(P + "flat", 1.0), game.roof_fade.get(P + "station", 1.0)])
	await down_from_flat()
	await talk(P + "ernesto")
	check(26, "The Flat above the Station is done: 30 more signatures, the yard is yours", status("flat") == "done" and signatures() >= 50 and game.state.flags.get("rice_village_homePlot", false), "signatures %d" % signatures())
	check(27, "40 signatures: the first page, and 30,000 lire for expenses", game.state.unlocks_seen.has("rice_village_page"), str(game.state.unlocks_seen))

# ---- Water for the Winter ---------------------------------------------------------------------------------------
func water() -> void:
	await talk_for(P + "battista", P + "water")
	check(30, "Barba Tista asks for water for the winter", status("water") == "active", status("water"))
	await gather_for("mine", "water", "stone", 6, "stone", 4)
	await gather_for("chop", "water", "wood", 6, "wood", 12, 24)
	await buy("battista", "metal", 2)
	check(31, "gather cobbles and wood, and buy metal at the machine shed", progress("water", "stone") >= 6 and progress("water", "wood") >= 6 and inv("metal") >= 3, "stone %d wood %d metal %d" % [inv("stone"), inv("wood"), inv("metal")])
	await walk_to(-36.6, -27.0, 1.0)
	var sl := await build(P + "sluice", [["bridgeDeck", -43, -29, 0], ["bridgeDeck", -42, -29, 0], ["bridgeDeck", -41, -29, 0],
		["bridgeDeck", -38, -29, 0], ["bridgeDeck", -39, -29, 0], ["bridgeDeck", -40, -29, 0],
		["pillar", -43, -28, 0], ["pillar", -38, -28, 0], ["lever", -38, -30, 0]])
	note("sluice: %s" % [sl])
	await frames(20)
	check(32, "rebuild the sluice: two pillars, a lever and a walkway across", progress("water", "sluice") == 1 and progress("water", "walk") == 1, str(sl))
	check(33, "the canal fills", game.state.flags.get("rice_village_canalFull", false) and game.village.get_node("rice_village_life/canal_water").visible, "")
	await walk_slow(-37.0, -28.6, 0.5); await walk_slow(-44.0, -28.6, 0.6, 40.0)
	check(34, "and you can walk across the sluice", game.player.pos.x < -43.0, str(game.player.pos))
	await walk_slow(-37.0, -28.6, 0.6, 40.0)
	await shot("sluice")
	await gather_to("clay", "clay", 4, 12)
	await gather_to("chop", "wood", 5)
	await walk_to(-36.0, 5.6, 1.0)
	var pd := await build(P + "paddy", [["waterwheel", -39, 10, 1], ["pump", -38, 10, 2], ["pipe", -37, 10, 1], ["pipe", -36, 10, 1], ["pipe", -35, 10, 1], ["pipe", -34, 10, 1]])
	note("paddy: %s" % [pd])
	await frames(30)
	check(35, "a waterwheel, a pump and pipes carry water to the winter paddy", progress("water", "paddy") == 1 and game.mech.fed.get(P + "paddy", false), str(pd))
	check(36, "the paddy floods", game.state.flags.get("rice_village_paddyFlooded", false) and game.village.get_node("rice_village_life/paddy_water").visible, "")
	await shot("paddy")
	await talk(P + "battista")
	check(37, "Water for the Winter is done", status("water") == "done" and signatures() >= 80, "signatures %d" % signatures())

# ---- Nonna's Bench ----------------------------------------------------------------------------------------------
func bench() -> void:
	await talk_for(P + "pierina", P + "bench")
	check(40, "Nonna asks for a bench by her paddy", status("bench") == "active", status("bench"))
	await gather_to("chop", "wood", 3)
	await walk_to(6.5, 32.6, 1.0)
	var bn := await build(P + "bench", [["bench", 9, 35, 0], ["flowerBed", 11, 35, 0]])
	note("bench: %s" % [bn])
	check(41, "build a bench and a flower bed under the poplars", progress("bench", "build") == 1, str(bn))
	await to_bench()
	var slept := await sleep_at(P + "waitingBench", 18)
	check(42, "sleep on the waiting-room bench until the evening", slept and float(game.state.time.minute) >= 18 * 60 and float(game.state.time.minute) < 19 * 60, Clock.text(game.state.time))
	await talk(P + "pierina")
	check(43, "sit with Nonna on her bench at dusk; she sings", progress("bench", "dusk") == 1 and status("bench") == "done", "nonna at %s" % game.npcs[P + "pierina"].pos)

# ---- Things from the Trains -------------------------------------------------------------------------------------
func lost_things() -> void:
	if status("lostthings") == "":
		await to_bench()
		await sleep_at(P + "waitingBench", 9)
		await talk_for(P + "ernesto", P + "lostthings")
	check(50, "Paletta asks you to find what passengers dropped", status("lostthings") in ["active", "done"], status("lostthings"))
	var lost: Array = Data.layout.nodes.filter(func(n): return n.kind == "fragment")
	lost.sort_custom(func(a, b): return a.z > b.z)   # this side of the line first
	for n in lost:
		if game.actions.node_state(n.id).get("ready_at", -1.0) > 0.0: continue   # already picked up on the way
		if n.z < -48.0 and game.player.pos.z > -44.0:
			await walk_to(2.0, -42.4, 0.8); await safe_to_cross()
		await walk_to(n.x, n.z, 0.5)
		await frames(10)
	if game.player.pos.z < -48.0:
		await walk_to(2.0, -51.4, 0.8); await safe_to_cross(); await walk_to(2.0, -42.0, 0.8)
	check(51, "pick up the five lost things along both sides of the line", progress("lostthings", "find") >= 5, "found %d" % progress("lostthings", "find"))
	await talk(P + "ernesto")
	check(52, "and hand them in at the lost-property cupboard", status("lostthings") == "done", status("lostthings"))

# ---- Matteo's Museum --------------------------------------------------------------------------------------------
func museum() -> void:
	await talk_for(P + "matteo", P + "museum")
	check(60, "Matteo asks for things for his museum", status("museum") == "active", status("museum"))
	for n in Data.layout.nodes.filter(func(x): return x.kind == "dig"):
		await walk_to(n.x + 1.0, n.z, 0.5)
		check("61-" + String(n.id), "the metal detector hums near %s" % n.id, game.actions.hum >= 2, "hum %d" % game.actions.hum)
		await face_and_press(n.id, n.x, n.z)
		await frames(20)
	check(62, "dig up an old coin, a mondina's badge and railway buttons", inv(P + "coin") >= 1 and inv(P + "badge") >= 1 and inv(P + "buttons") >= 1, str(game.state.inventory))
	await talk(P + "matteo")
	check(63, "Matteo labels them for the museum", status("museum") == "done", status("museum"))
