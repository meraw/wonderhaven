extends "res://tests/full_base.gd"
## Boccapioppo (river_town) with real input.
## Part one, the map, the buildings and scenery (checks r1-r16): from the bus stop on the levee into Ermes's house at
## the levee's foot, down into the town (Pierina's house, the piazza, Rina's bar, Primo's workshop), north over the
## Roman bridge to the east bank and the sawmill (the Alpine river can't be waded), back onto the floodplain to Gildo
## and Mattia's shack and the stranded houseboat (sleep there until morning), up the ramp into the empty dance hall,
## through the breach, and to the canal that keeps you on the map.
## Part two, every request (checks s1-s18): see requests() below.
## It starts as if you had come by Monteforchetta's bus with its main story done (arrive_as_if_played).
## Run: TIMEOUT=30000 ./play.sh res://tests/play_river_town.gd /tmp/out --island=river_town --limit=29000
##      (--part=requests plays part two only; --from=<section> and --to=<section> start and stop at a request)

const RiverTown := preload("res://scripts/locations/river_town.gd")

func at(x: float, z: float, tol: float = 1.6) -> bool:
	return Vector2(game.player.pos.x - x, game.player.pos.z - z).length() < tol

func building(id: String) -> Dictionary:
	return Data.layout.buildings.filter(func(b): return b.id == id)[0]

## Is the player inside the room, with its roof faded away?
func inside(id: String) -> bool:
	var b := building(id)
	var o: Node3D = game.village.objects[id]
	var room := Interiors.room(b, o.position.y)
	return room.has_point(Vector3(game.player.pos.x, room.position.y + 1.0, game.player.pos.z))

## Walk to a room's spot along the nav graph (in through its door), let the roof fade, take a picture.
func enter(id: String, name: String) -> bool:
	var spot: Array = Data.layout.nav_nodes.get(id + ":spot", [])
	if spot.is_empty(): return false
	await walk_to(spot[0], spot[1], 0.7)
	await wait(1.0)
	await shot(name)
	return inside(id) and float(game.roof_fade.get(id, 1.0)) < 0.2

func play() -> void:
	# reached by Monteforchetta's bus line: arrive as a player who has played its main story would
	if not game.shot_cfg.has("from"): await arrive_as_if_played(["hearthglow"])
	var s: Dictionary = game.state
	s.tutorial = Tutorial.new_state(false, true)   # no guided day here yet: just walk
	s.time.minute = 10 * 60.0
	game.hud.apply_reveals(); await frames(10)
	if game.shot_cfg.get("part", "") == "shots": await shots(); return
	if game.shot_cfg.get("part", "") == "crossing": await cross_check(); return
	if game.shot_cfg.get("part", "") != "requests": await walk_around()
	await requests()

## Pictures of the places the story changes, for the pull request (--part=shots; RENDERER=forward_plus for Forward+).
## Test-only: it sets the story's flags and the clock directly instead of playing up to them.
func view(x: float, z: float, yaw: float, pitch: float, dist: float, h: float, name: String) -> void:
	game.state.time.minute = h * 60.0
	game.player.teleport(x, z)
	for a in game.npcs.values(): a.teleport_home()
	game.cam.yaw = yaw; game.cam.pitch = pitch; game.cam.dist = dist
	game.cam.limits.explore = [2.0, 120.0, 0.05, 1.5]
	game.cam.update(0.016, game.player.pos); game.cam.snap()
	await wait(2.5)
	await shot(name)

## Walks over the pontoon bridge from the bridge checkpoint, logging where you are (a check while developing).
func cross_check() -> void:
	game.load_state(SaveSystem.read("rt_bridge"))
	await await_rebuild(20.0)
	await walk_to(23.5, 10.5, 1.0)
	await walk_direct(24.5, 13.5, 0.6)
	note("start %s" % game.player.pos)
	game.cam.yaw = -PI / 2.0; game.cam.pitch = 0.8; game.cam.dist = 12.0
	var t0 := Time.get_ticks_msec()
	key(KEY_W, true)
	while Time.get_ticks_msec() - t0 < 40000:
		steer(38.6, 13.5)
		await wait(1.0)
		note("at %s" % game.player.pos)
		if game.player.pos.x > 38.0: break
	key(KEY_W, false)
	await shot("cross-check")
	check("x", "Walked across the pontoon bridge", game.player.pos.x > 37.5 and game.player.pos.y > -0.3, str(game.player.pos))

func story_at(flags: Array) -> void:
	for f in flags: game.state.flags[P + f] = true
	game.request_rebuild()
	await await_rebuild()

func shots() -> void:
	game.shot_cfg["weather"] = "clear"
	await view(26.0, 9.0, 2.2, 0.42, 12.0, 11.0, "pumping-house")
	await view(-41.5, 23.4, -2.2, 0.35, 8.0, 9.5, "ermes-waits")
	await story_at(["welcomed", "bridge_open", "piazza_drained"])
	await view(4.0, 6.0, 0.6, 0.55, 15.0, 12.5, "piazza-drained")
	await story_at(["hall_ready", "hall_open"])
	await view(9.0, 31.5, -1.3, 0.4, 13.0, 21.2, "dance-night")
	await story_at(["launched"])
	await view(-18.6, 33.0, 0.5, 0.45, 13.0, 9.0, "houseboat-afloat")
	await story_at(["monster_seen"])
	await view(6.4, -4.2, 3.14, 0.35, 5.0, 10.0, "bar-photo")
	await story_at(["wall_built", "storm"])
	Daylight.force(game.state, "rain", 8.0)
	game.shot_cfg.erase("weather")
	await view(-3.0, 23.5, -0.4, 0.38, 16.0, 22.0, "storm-night")
	await story_at(["flood_over"])
	game.shot_cfg["weather"] = "clear"
	await view(5.0, 16.5, 3.0, 0.5, 14.0, 10.0, "after-the-storm")

func walk_around() -> void:
	var s: Dictionary = game.state
	check("r1", "A new game started with --island=river_town begins at the bus stop on the levee",
		Data.island == "river_town" and at(-45, 22) and game.player.pos.y > 2.5, "%s at %s" % [Data.island, game.player.pos])
	await shot("bus-stop")
	check("r2", "Ermes's keeper's house at the foot of the levee: in through its door, the roof fades",
		await enter("river_town_ermes_house", "ermes-house"), str(game.player.pos))
	await walk_to(-1, 15)
	check("r3", "Walked down from the levee into the town", at(-1, 15) and game.player.pos.y < 1.0, str(game.player.pos))
	check("r4", "Pierina's house: in through its door", await enter("river_town_pierina_house", "pierina-house"), str(game.player.pos))
	await walk_to(5, 4)
	check("r5", "Reached the piazza, the lowest part of town, still under a little water", at(5, 4) and game.player.pos.y < 0.45 and game.village.objects.has("river_town_pond"), str(game.player.pos))
	await shot("piazza")
	check("r6", "Rina's bar: in past the awning, behind her counter", await enter("river_town_bar", "bar"), str(game.player.pos))
	check("r7", "Primo's workshop: in through its door", await enter("river_town_workshop", "workshop"), str(game.player.pos))
	# north to the Roman bridge, and over it to the east bank
	await walk_to(21.5, -44)
	await walk_direct(RiverTown.alpine_center(RiverTown.ROMAN_Z), RiverTown.ROMAN_Z, 0.8)
	var top: float = game.player.pos.y
	await shot("roman-bridge")
	await walk_direct(36.5, -44, 0.8)
	check("r8", "Crossed the Roman bridge on foot, over the top of its hump", at(36.5, -44) and top > 1.6, "top %.2f, now %s" % [top, game.player.pos])
	await walk_to(45.9, 21)
	check("r9", "Down the east bank through the poplar plantation, under the sawmill's open shed", at(45.9, 21), str(game.player.pos))
	await shot("sawmill")
	await walk_to(38.8, 9.5)
	var bank := RiverTown.alpine_center(9.5) + RiverTown.ALPINE_HALF
	await walk_direct(bank + 0.8, 9.5, 0.6)
	var reached: bool = game.player.pos.x < bank + 1.6
	await walk_direct(RiverTown.alpine_center(9.5), 9.5, 0.5, 6.0)
	check("r10", "The Alpine river stops you at its bank: no wading across before the pontoon bridge exists",
		reached and game.player.pos.x > bank - 1.0, "bank at %.1f, stopped at %s" % [bank, game.player.pos])
	# back over the bridge and onto the floodplain
	check("r11", "Gildo and Mattia's fishing shack by the Po: in through its door", await enter("river_town_shack", "shack"), str(game.player.pos))
	await walk_to(-19.2, 29)
	await walk_direct(-22.4, 29.5, 0.5)
	await wait(1.0)
	check("r12", "The stranded houseboat: in through the stern door", inside("river_town_houseboat") and float(game.roof_fade.get("river_town_houseboat", 1.0)) < 0.2, str(game.player.pos))
	await shot("houseboat")
	s.time.minute = 22 * 60.0
	var day := int(s.time.day)
	var slept := await sleep_at("river_town_bed", 6)
	check("r13", "Slept in the houseboat until dawn the next day", slept and int(s.time.day) == day + 1 and absf(s.time.minute - 6 * 60.0) < 2.0, Clock.text(s.time))
	# up the ramp and into Wanda's dance hall, standing empty on its stilts
	check("r14", "Up the ramp and into the empty dance hall, on its raised floor", await enter("river_town_dance_hall", "dance-hall") and game.player.pos.y > RiverTown.DANCE_H - 0.1, str(game.player.pos))
	# through the breach, from the floodplain back into the town
	await walk_to(6.6, 31.5)
	await walk_direct(5, 26.5, 1.0)
	await walk_direct(5, 22, 0.8)
	var low: float = game.player.pos.y
	await shot("breach")
	await walk_direct(5, 16, 1.0)
	check("r15", "Walked through the breach in the levee, well below its crest", at(5, 16) and low < RiverTown.LEVEE_H - 1.5, "in the gap at %.2f" % low)
	# the canal at the west edge keeps you on the map
	await walk_to(-45, 22)
	await walk_direct(-62, 22, 0.5, 25.0)
	var edge: float = RiverTown.CANAL_W + RiverTown.CANAL_HALF
	check("r16", "The canal at the west end of the levee keeps you on the map: you reach its bank and stop",
		game.player.pos.x < edge + 2.0 and game.player.pos.x > edge - 0.5, "canal's edge at %.1f, stopped at %s" % [edge, game.player.pos])
	await shot("west-canal")

# ---- Part two: every request ---------------------------------------------------------------------------------------
const P := "river_town_"

## A run can use a smaller window than the game's 1280x720 canvas (software rendering is slow): mouse events are
## given in window pixels, so canvas positions (buttons, unprojected cells) are mapped first. At full size this
## changes nothing.
func _to_window(p: Vector2) -> Vector2: return get_viewport().get_final_transform() * p
func mouse_move(p: Vector2, rel: Vector2 = Vector2.ZERO) -> void: super.mouse_move(_to_window(p), rel)
func mouse_button(p: Vector2, button: int, pressed: bool) -> void: super.mouse_button(_to_window(p), button, pressed)

func qs(id: String) -> String: return String(game.state.quests.get(P + id, {}).get("status", ""))
func stage(id: String) -> int: return game.story.engine.current_stage(P + id)
func pts() -> int: return LocationMeter.points(game.state, "river_town")
func reading() -> String: return LocationMeter.reading(LocationMeter.def("river_town"), pts())
func flag(f: String) -> bool: return game.state.flags.get(P + f, false)
func hour() -> float: return float(game.state.time.minute) / 60.0

## talk() from full_base, for conversations that can end with the world being built again (a WORLD_FLAG set): when
## frames are slow the old scene is gone before the next look at it, so stop looking once it is.
var _game_id := 0
func talk(id: String, accept: bool = true) -> bool:
	_game_id = game.get_instance_id()
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
			await tap(KEY_1 + idx)
		else: await tap(KEY_E)
	return true

## A step that reshapes the place (one of its WORLD_FLAGS) has the world built again where you stand once the
## conversation ends: wait for the new scene and follow it.
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

## Talk to someone and pick one kind of choice (a shop, say), accepting offers and payments on the way like talk().
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
		if kinds.has(want): await tap(KEY_1 + kinds.find(want)); return true
		var idx: int = kinds.find("yes") if kinds.has("yes") else (kinds.find("pay") if kinds.has("pay") else kinds.find("bye"))
		await tap(KEY_1 + idx)
	return false

## Places a piece with its corner cell at (i, k), clicking the middle of its whole footprint (for a piece two cells
## wide, the middle of its first cell is exactly where the grid rounds to the next cell).
func place_piece(id: String, i: int, k: int, y: float, r: int = 0) -> String:
	var fp := BuildGrid.footprint(Data.piece(id), r)
	var status := await place_at(i + fp.x / 2.0 - 0.5, k + fp.y / 2.0 - 0.5, y, r)
	var ok: bool = game.state.placements.any(func(p): return p.id == id and int(p.i) == i and int(p.k) == k)
	note("placed %s at %d, %d: %s (%s)" % [id, i, k, ok, status])
	return status

## Opens someone's shop through their conversation and waits for the panel to be laid out.
func open_shop(id: String) -> bool:
	if not await choose(id, "shop"): note("no shop option at %s" % id); return false
	for k in 80:
		await frames(4)
		if game.panels.current == "shop": break
		if game.mode == "dialogue" and game.dialogue.choices.is_empty(): await tap(KEY_E)
	await frames(20)
	if game.panels.current != "shop": note("%s's shop didn't open (panel '%s')" % [id, game.panels.current])
	return game.panels.current == "shop"

## Buy a line of someone's shop, n times, through the shop panel.
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

## Sell everything of one kind to someone.
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

## Nap on the nearest bench (or sleep in the houseboat) until a wake-up hour.
func nap_until(h: int) -> bool:
	var p: Vector3 = game.player.pos
	var best := {}
	for f in Data.layout.features:
		if f.kind in ["bench", "rest"] and (best.is_empty() or Vector2(f.x - p.x, f.z - p.z).length() < Vector2(best.x - p.x, best.z - p.z).length()): best = f
	await walk_to(best.x, best.z, 1.1)
	return await sleep_at(best.id, h)

## The first wake-up time on the sleep panel at least `gap` hours from now (to let things grow back).
func next_wake(gap: float) -> int:
	for w in [6, 9, 12, 18, 21]:
		if fposmod(w - hour(), 24.0) >= gap: return w
	return 6

## Wait, standing where you are, until the clock passes an hour (a minute of game time a second).
func wait_until(h: float, max_s: float = 3600.0) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		var now := hour()
		if now >= h and now < h + 1.0: return
		await wait(1.0)

## Walk onto a lost thing (they're picked up as you step on them).
func pick_up(node: String) -> bool:
	var n := Data.node_def(node)
	var have: int = inv(n.gives.keys()[0])
	await walk_to(n.x, n.z, 0.5)
	await walk_direct(n.x, n.z, 0.35, 6.0)
	await frames(20)
	return inv(n.gives.keys()[0]) > have

## Like gather_until, but when nothing of that kind has grown back yet, nap until it has (the game's clock runs slow
## when frames are slow, so standing and waiting could take an age).
func gather_more(kind: String, test: Callable, only: Array = [], rounds: int = 30) -> bool:
	for r in rounds:
		if test.call(): return true
		var ready: Array = Data.layout.nodes.filter(func(n): return n.kind == kind and (only.is_empty() or only.has(n.id)) and game.actions.ready(n))
		if ready.is_empty(): note("nothing to %s has grown back: nap" % kind); await nap_until(next_wake(4.0)); continue
		await gather_until(kind, test, only, 1)
	return test.call()

## Gather an item from the nodes that give it (Boccapioppo's sand, mushrooms) until you have enough.
func gather_item(item: String, need: int, rounds: int = 20) -> bool:
	var ids: Array = Data.layout.nodes.filter(func(n): return n.get("gives", {}).has(item)).map(func(n): return n.id)
	var kind: String = Data.node_def(ids[0]).kind
	return await gather_more(kind, func(): return inv(item) >= need, ids, rounds)

## Part two, every request, in sections. After each one the state is kept as a checkpoint (rt_<section>), so a run can
## start from a later section with --from=<section> (a test-only shortcut while developing; a full run plays them all).
const SECTIONS := ["welcome", "bridge", "piazza", "crossing", "dancehall", "houseboat", "catfish", "lost", "levee"]

func requests() -> void:
	var from := String(game.shot_cfg.get("from", "welcome"))
	var k0 := SECTIONS.find(from)
	if k0 > 0:
		var saved: Dictionary = SaveSystem.read("rt_" + SECTIONS[k0 - 1])
		if saved.is_empty(): check("from", "A checkpoint to start from", false, "no rt_%s" % SECTIONS[k0 - 1]); return
		game.load_state(saved)
		await await_rebuild(20.0)
		await frames(20)
	else:
		var s: Dictionary = game.state
		note("requests: day %d %s" % [int(s.time.day), Clock.text(s.time)])
		if hour() < 7.0 or hour() > 18.0: await nap_until(9)
	var k1 := SECTIONS.find(String(game.shot_cfg.get("to", "levee")))   # --to=<section>: stop after it
	for k in range(maxi(k0, 0), (k1 if k1 >= 0 else SECTIONS.size() - 1) + 1):
		note("section %s: day %d %s" % [SECTIONS[k], int(game.state.time.day), Clock.text(game.state.time)])
		await call("sec_" + SECTIONS[k])
		SaveSystem.write("rt_" + SECTIONS[k], game.snapshot())

func sec_welcome() -> void:
	var s: Dictionary = game.state
	# ---- 1. Straight to Work (Ermes, at the bus stop)
	await talk(P + "ermes")
	var accepted: bool = qs("welcome") == "active" and s.flags.get("hasTool", false)
	await gather_item(P + "sand", 5)
	await talk(P + "ermes")   # the sand for the patch
	await talk(P + "rina")    # coffee
	await talk(P + "ermes")   # tell him you've found your way
	check("s1", "Straight to Work: sand from the sandbank for Ermes's patch, coffee at Rina's, and the gauge comes down a metre",
		accepted and qs("welcome") == "done" and pts() == 100 and reading() == "6.40 m" and flag("welcomed"), "%s, gauge %s" % [qs("welcome"), reading()])
	await shot("welcome-done")

func sec_bridge() -> void:
	var s: Dictionary = game.state
	# ---- 2. The Pontoon Bridge (Tullio, by his sunken ferry)
	await talk(P + "tullio")
	var b_ok: bool = qs("bridge") == "active"
	await buy("primo", "metal", 1)
	var silt: Array = Data.layout.nodes.filter(func(n): return n.kind == "clay" and not n.has("gives")).map(func(n): return n.id)
	await gather_more("clay", func(): return int(q(P + "bridge").progress.get("clay", 0)) >= 6, silt)
	await gather_more("chop", func(): return int(q(P + "bridge").progress.get("wood", 0)) >= 16 and inv("wood") >= 19)
	await talk(P + "ines")   # the Pontoon plans, over the Roman bridge
	var plans: bool = s.blueprints.has("pontoon")
	await walk_to(23.5, 10.5, 1.0); await walk_direct(24.5, 11.0, 0.6)
	await open_build(P + "bridge")
	await select_piece("pontoon")
	for i in [27, 29, 31, 33, 35]: await place_piece("pontoon", i, 13, 0.1, 1)
	var path_done: bool = stage("bridge") >= 3
	await shot("pontoons")
	await select_piece("railing")
	for i in [28, 30, 32, 34]: print("   railing: ", await place_at(i, 13, -0.05, 0))
	if not game.story.engine.is_ready(P + "bridge"):   # railings that won't sit on a pontoon go on planks laid across it
		await select_piece("bridgeDeck")
		for i in [28, 30, 32, 34]: print("   plank: ", await place_at(i, 13, -0.05))
		await select_piece("railing")
		for i in [28, 30, 32, 34]: print("   railing: ", await place_at(i, 13, 0.1, 0))
	var rails_done: bool = game.story.engine.is_ready(P + "bridge")
	await leave_build()
	# line up with the middle of the pontoons' deck (a metre wide) at the ferry landing, then walk straight over
	await walk_direct(24.6, 13.6, 0.5); await walk_direct(25.6, 13.6, 0.25, 15.0)
	await walk_direct(38.6, 13.6, 0.6, 90.0)
	var crossed: bool = game.player.pos.x > 37.5 and game.player.pos.y > -0.3
	note("crossed to %s" % game.player.pos)
	await shot("pontoon-bridge-crossed")
	await talk(P + "tullio")
	check("s2", "The Pontoon Bridge: materials, the plans from Ines over the Roman bridge, a row of pontoons moored bank to bank, railings, and you walk across",
		b_ok and plans and path_done and rails_done and crossed and qs("bridge") == "done" and flag("bridge_open") and pts() == 200,
		"plans=%s path=%s rails=%s crossed=%s at %s, %s, gauge %s" % [plans, path_done, rails_done, crossed, game.player.pos, qs("bridge"), reading()])

func sec_piazza() -> void:
	var s: Dictionary = game.state
	# ---- 3. Pump Out the Piazza (Rina): a waterwheel in the Alpine river turns the pumping house's pump
	await talk(P + "rina")
	var pz_ok: bool = qs("piazza") == "active"
	await buy("primo", "metal", 1)
	await gather_more("chop", func(): return int(q(P + "piazza").progress.get("wood", 0)) >= 8 and inv("wood") >= 8)
	await talk(P + "ermes")   # about the old pumping house
	await walk_to(24.6, 7.6, 0.8)
	await open_build(P + "works")
	await select_piece("waterwheel"); print("   waterwheel: ", await place_at(27, 5, 0.1, 1))
	await select_piece("shaft")
	for i in [26, 25, 24, 23]: print("   shaft: ", await place_at(i, 5, 0.25, 1))
	var fed: bool = game.mech.fed.get(P + "pump", false)
	await shot("pump-turning")
	await leave_build()
	await talk(P + "rina")
	var drained := await await_rebuild()
	await walk_to(5, 4); await shot("piazza-drained")
	check("s3", "Pump Out the Piazza: a waterwheel by the quay powers the old pumping house, the world is rebuilt and the piazza is dry",
		pz_ok and fed and drained and qs("piazza") == "done" and not game.village.objects[P + "pond"].visible and Data.world_flags.has(P + "piazza_drained") and pts() == 300,
		"fed=%s rebuilt=%s %s pond=%s gauge %s" % [fed, drained, qs("piazza"), game.village.objects[P + "pond"].visible, reading()])

func sec_crossing() -> void:
	# villagers use the bridge you built: Tullio crosses it after lunch, on his way from the bar to the far bank
	if hour() < 12.0 or hour() > 14.0: await nap_until(12)
	await wait_until(14.0)
	var crossing_seen := false
	var t0 := Time.get_ticks_msec()
	while not crossing_seen and hour() < 18.0 and Time.get_ticks_msec() - t0 < 2400000:
		var tp: Vector3 = game.npcs[P + "tullio"].pos
		crossing_seen = tp.x > 26.5 and tp.x < 37.0 and absf(tp.z - 13.5) < 1.6 and tp.y > -0.3
		await wait(0.5)
	await shot("tullio-crossing")
	check("s4", "Villagers walk across the bridge you built: Tullio crosses it on his pontoons", crossing_seen, "Tullio at %s, %s" % [game.npcs[P + "tullio"].pos, Clock.text(game.state.time)])

func sec_dancehall() -> void:
	var s: Dictionary = game.state
	# ---- 4. Saturday at the Dance Hall (Wanda)
	await talk(P + "wanda")
	var dh_ok: bool = qs("dancehall") == "active"
	await buy("primo", "crystal", 2)
	await gather_more("mine", func(): return inv("stone") >= 1)
	await gather_more("chop", func(): return int(q(P + "dancehall").progress.get("wood", 0)) >= 15 and inv("wood") >= 17)
	await walk_to(12.4, 31.5, 0.6); await walk_direct(12.8, 31.5, 0.4)
	await open_build(P + "hall")
	await select_piece("floor")
	for i in range(14, 20): print("   floor: ", await place_at(i, 31, 0.9))
	await select_piece("platform"); await place_piece("platform", 18, 29, 0.9, 0)
	await select_piece("counter"); await place_piece("counter", 14, 29, 0.9, 0)
	await select_piece("lamp"); print("   lamp: ", await place_at(12, 29, 0.9)); print("   lamp: ", await place_at(12, 33, 0.9))
	await select_piece("chair")
	for i in [15, 16, 17]: print("   chair: ", await place_at(i, 33, 0.9, 0))
	await tap(KEY_ESCAPE)
	for p in game.state.placements:
		if p.id == "chair":
			await place_at(p.i, p.k, 1.4)
			await ui_click("sw_7bd389")
			break
	var fitted: bool = stage("dancehall") >= 2
	await shot("dance-hall-fitted")
	await leave_build()
	await talk(P + "pierina")   # spread the word
	await nap_until(21)
	var hall := Rect2(11.5, 28.5, 9.0, 6.0)
	var dancers := 0
	for k in 60:
		dancers = game.npcs.values().filter(func(a): return a.present and hall.has_point(Vector2(a.pos.x, a.pos.z))).size()
		if dancers >= 7: break
		await wait(1.0)
	await walk_to(12.8, 31.5, 0.6)
	await shot("first-dance")
	await talk(P + "wanda")
	var lit := await await_rebuild()
	var bulbs: Node3D = game.village.objects[P + "dance_hall"].get_node("dance_bulbs")
	var glow: float = ((bulbs.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier
	await shot("dance-hall-lit")
	check("s5", "Saturday at the Dance Hall: floor, stage, lamps, bar, seats and colour; after 8 the town comes to dance, and the hall's bulbs light up",
		dh_ok and fitted and dancers >= 7 and lit and glow > 1.0 and qs("dancehall") == "done" and pts() == 400,
		"fitted=%s dancers=%d lit=%s glow=%.1f %s gauge %s" % [fitted, dancers, lit, glow, qs("dancehall"), reading()])

func sec_houseboat() -> void:
	var s: Dictionary = game.state
	var silt: Array = Data.layout.nodes.filter(func(n): return n.kind == "clay" and not n.has("gives")).map(func(n): return n.id)
	# ---- 5. A Roof That Floats (Ermes): patch, slipway, launch at dawn, a cosy cabin
	if qs("houseboat") == "": await talk(P + "ermes")
	var hb_ok: bool = qs("houseboat") == "active"
	await gather_more("clay", func(): return int(q(P + "houseboat").progress.get("clay", 0)) >= 4, silt)
	await gather_more("chop", func(): return int(q(P + "houseboat").progress.get("wood", 0)) >= 8 and inv("wood") >= 6)
	await talk(P + "tullio")   # caulking
	await walk_to(-19.2, 29.0, 1.0); await walk_direct(-20.4, 31.8, 0.4)
	await open_build(P + "mooring")
	await select_piece("bridgeDeck")
	print("   slipway: ", await place_at(-24, 32, BuildGrid.ground_at(-24, 32)))
	print("   slipway: ", await place_at(-24, 33, 0.1))
	if stage("houseboat") < 3:
		await select_piece("bridgePost"); print("   post: ", await place_at(-24, 33, 0.1))
		await select_piece("bridgeDeck"); print("   slipway: ", await place_at(-24, 33, 1.4))
	var slip: bool = stage("houseboat") >= 3
	await shot("slipway")
	await leave_build()
	await walk_to(-19.2, 29.0, 1.0); await walk_direct(-22.4, 29.5, 0.5)
	await sleep_at(P + "bed", 6)
	await talk(P + "ermes")   # at his gauge at dawn: launch
	var launched := await await_rebuild()
	var boat: Dictionary = building(P + "houseboat")
	var door: Array = Data.layout.nav_nodes.houseboat
	await walk_to(door[0], door[1], 0.5); await walk_direct(boat.x + 2.6, boat.z, 0.4)
	await wait(1.0)
	var aboard: bool = inside(P + "houseboat") and game.player.pos.y > 0.0
	await shot("houseboat-afloat")
	await buy("rina", "fabric", 1)
	await buy("primo", "crystal", 1)
	await gather_more("flowers", func(): return inv("flowers") >= 1, Data.layout.nodes.filter(func(n): return n.kind == "flowers" and not n.has("gives")).map(func(n): return n.id))
	await gather_more("chop", func(): return inv("wood") >= 4)
	await walk_to(door[0], door[1], 0.5); await walk_direct(boat.x + 3.2, boat.z, 0.3)
	await open_build(P + "cabin")
	# along the cabin's north side, leaving the way from the door to the bed free
	await select_piece("rug"); await place_piece("rug", -24, 35, 0.2, 0)
	await select_piece("table"); print("   table: ", await place_at(-24, 35, 0.25))
	await select_piece("chair"); print("   chair: ", await place_at(-23, 35, 0.25, 3))
	await select_piece("lamp"); print("   lamp: ", await place_at(-25, 35, 0.2))
	await tap(KEY_ESCAPE)
	for p in game.state.placements:
		if p.id == "table" and p.k >= 34.0:
			await place_at(p.i, p.k, 0.85)
			await ui_click("sw_ffd166")
			break
	var cosy: bool = stage("houseboat") >= 5 or game.story.engine.is_ready(P + "houseboat")
	await shot("cabin-cosy")
	await leave_build()
	await talk(P + "ermes")
	check("s6", "A Roof That Floats: a slipway into the backwater, the launch at dawn moves the houseboat to her mooring, you walk aboard and furnish her cabin",
		hb_ok and slip and launched and boat.get("afloat", false) and aboard and cosy and qs("houseboat") == "done",
		"slip=%s launched=%s aboard=%s at %s cosy=%s %s" % [slip, launched, aboard, game.player.pos, cosy, qs("houseboat")])
	await walk_to(door[0], door[1], 0.5); await walk_direct(boat.x + 3.0, boat.z + 0.5, 0.3); await walk_direct(boat.x - 1.2, boat.z + 0.5, 0.3)
	var sleep_spot := feature(P + "bed")
	check("s7", "Her bed went with her: you sleep aboard at her mooring", Interiors.room(boat, float(boat.y)).has_point(Vector3(sleep_spot.x, float(boat.y) + 0.5, sleep_spot.z)) and await sleep_at(P + "bed", 18), "bed at %.1f, %.1f" % [sleep_spot.x, sleep_spot.z])

func sec_catfish() -> void:
	var s: Dictionary = game.state
	# ---- 6. The Monster of the Po (Gildo and Mattia), after dark where the rivers meet
	await talk(P + "gildo")
	var cf_ok: bool = qs("catfish") == "active"
	await talk(P + "primo")   # a stronger line
	await nap_until(21)
	await gather_node(P + "fish4")
	for k in 3:
		if inv(P + "whisker") > 0: break
		await gather_node(P + "fish4")
	var hooked: bool = inv(P + "whisker") > 0
	await shot("monster")
	await talk(P + "mattia")   # asleep in the shack: wake him for the photo
	await talk(P + "gildo")
	var photo := await await_rebuild()
	check("s8", "The Monster of the Po: Primo's line, the monster bites at night where the rivers meet, Mattia's photo, and it hangs in Rina's bar",
		cf_ok and hooked and photo and qs("catfish") == "done" and Data.world_flags.has(P + "monster_seen"), "hooked=%s rebuilt=%s %s" % [hooked, photo, qs("catfish")])

func sec_lost() -> void:
	var s: Dictionary = game.state
	# ---- 7. Ines's Runaway Logs and the six lost things: ask everyone, one tour to find them, then hand them back
	await talk(P + "ines")
	for who in ["pierina", "rina", "wanda", "primo", "mattia", "tullio"]: await talk(P + who)
	var asked: int = ["logs", "lost_clock", "lost_gnome", "lost_trophy", "lost_photo", "lost_walkman", "lost_oar"].filter(func(id): return qs(id) == "active").size()
	var found := 0
	for id in ["lost_photo", "log2", "log4", "log3", "lost_gnome", "lost_trophy", "log1", "lost_oar", "log5", "log0", "lost_walkman", "lost_clock"]:
		if await pick_up(P + id): found += 1
		else: note("could not pick up %s" % id)
	await shot("found-everything")
	for who in ["pierina", "rina", "wanda", "primo", "mattia", "tullio", "ines"]: await talk(P + who)
	var returned: int = ["logs", "lost_clock", "lost_gnome", "lost_trophy", "lost_photo", "lost_walkman", "lost_oar"].filter(func(id): return qs(id) == "done").size()
	check("s9", "Ines's six runaway logs and the six lost things: found once each along the banks and handed back",
		asked == 7 and found == 12 and returned == 7 and inv(P + "log") == 0, "asked %d, found %d of 12, returned %d" % [asked, found, returned])
	check("s10", "The flood gauge counts it all: a metre per main request, half a metre per side request, ten centimetres per lost thing",
		pts() == 400 + 150 + 60 and reading() == "1.30 m" and s.flags.get(P + "mooring_plot", false) and s.blueprints.has("poweredLamp") and s.flags.get(P + "mooring_garden", false),
		"gauge %s (%d cm); plot=%s lamp plans=%s garden=%s" % [reading(), pts(), s.flags.get(P + "mooring_plot", false), s.blueprints.has("poweredLamp"), s.flags.get(P + "mooring_garden", false)])

func sec_levee() -> void:
	var s: Dictionary = game.state
	# ---- 8. Close the Breach (Ermes), the finale
	await talk(P + "ermes")
	var lv_ok: bool = qs("levee") == "active" and s.blueprints.has("sandbags")
	await buy("rina", "fabric", 3)
	await gather_more("mine", func(): return int(q(P + "levee").progress.get("stone", 0)) >= 12 and inv("stone") >= 12, [], 30)
	var sand_ids: Array = Data.layout.nodes.filter(func(n): return n.get("gives", {}).has(P + "sand")).map(func(n): return n.id)
	await gather_more("clay", func(): return int(q(P + "levee").progress.get("sand", 0)) >= 20, sand_ids, 20)
	print("   finale materials: ", s.inventory)
	await walk_to(5.0, 17.4, 0.6)
	await open_build(P + "breach")
	for i in range(2, 8):
		await select_piece("stoneBlock")
		var g := BuildGrid.ground_at(i, 21)
		print("   block: ", await place_at(i, 21, g))
		await select_piece("sandbags")
		var top := g + 1.0
		while top < 2.2:
			print("   sandbags: ", await place_at(i, 21, top))
			top += 0.5
	var sealed: bool = stage("levee") >= 2 and flag("wall_built")
	await shot("breach-wall")
	await leave_build()
	if hour() < 20.0 or hour() >= 23.0: await nap_until(21)
	await talk(P + "ermes")   # the storm comes over the mountains
	var storm := await await_rebuild()
	await frames(60)
	var crest := 0
	for a in game.npcs.values():
		if a.present and a.pos.y > RiverTown.LEVEE_H - 0.5: crest += 1
	var risen: bool = game.village.water.position.y > Heightfield.WATER_Y + 0.2
	var raining: bool = Daylight.forced(game.state) == "rain" and String(game.weather_now.get("type", "")) == "rain"
	await shot("storm-night")
	check("s11", "Close the Breach: a wall of stone blocks and sandbags seals the gap, then the storm night: rain, the rivers up to their brims, the whole town on the levee",
		lv_ok and sealed and storm and risen and raining and crest >= 8 and flag("storm"), "sealed=%s storm=%s risen=%s raining=%s on the crest %d" % [sealed, storm, risen, raining, crest])
	var t_wait := Time.get_ticks_msec()
	while hour() >= 1.0 and Time.get_ticks_msec() - t_wait < 5400000: await wait(1.0)   # keep watch until midnight
	await talk(P + "ermes")   # the peak, and it holds
	var over := await await_rebuild()
	await shot("after-the-storm")
	check("s12", "The levee holds: past midnight the river peaks below the wall, the flood is over, the rivers go back down and the bus line goes on to Casalrana",
		over and qs("levee") == "done" and flag("flood_over") and absf(game.village.water.position.y - Heightfield.WATER_Y) < 0.01 and pts() == 810 - 100
		and Travel.on_map(Data.island_def("rice_village"), game.state.flags, "river_town"),
		"%s, water %.2f, gauge %s" % [qs("levee"), game.village.water.position.y, reading()])
