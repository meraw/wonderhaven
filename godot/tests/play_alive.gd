extends "res://tests/full_base.gd"

var events: Array = []
var papers: Array = []

func of(type: String) -> Array: return events.filter(func(e): return e.type == type)

func cands(c: Vector2, r: int = 4) -> Array:
	var out: Array = []
	for di in range(-r, r + 1):
		for dk in range(-r, r + 1): out.append(Vector2(floor(c.x) + di, floor(c.y) + dk))
	out.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	return out

func put(id: String, i: float, k: float, r: int = 0) -> Dictionary:
	var zone := BuildGrid.zone_at(game.placement_ctx().zones, i, k)
	var pl := {"uid": int(game.state.next_uid), "id": id, "i": i, "k": k, "r": r, "y": BuildGrid.suggest_bottom(id, i, k, r, 10.0, game.state.placements, zone)}
	game.state.next_uid = int(pl.uid) + 1
	return pl if game.commit_place(pl, false, true).ok else {}

func put_near(id: String, c: Vector2, test: Callable = func(_p): return true) -> Dictionary:
	for cc in cands(c):
		var pl := put(id, cc.x, cc.y)
		if pl.is_empty(): continue
		if test.call(pl): return pl
		game.commit_remove(int(pl.uid), true)
	return {}

func choices_up(id: String) -> void:
	var a = game.npcs[id]
	game.stand_up()
	for off in [Vector2(0.5, 1.5), Vector2(1.5, 0.5), Vector2(-1.5, 0.5), Vector2(0.5, -1.5), Vector2(-0.5, 1.5), Vector2(1.2, -1.2)]:
		game.player.teleport(a.pos.x + off.x, a.pos.z + off.y, atan2(-off.x, -off.y)); game.cam.snap(); await frames(5)
		if game.target != null and String(game.target.id) == "npc:" + id: break
	await tap(KEY_E)
	for n in 80:
		await frames(4)
		if not game.dialogue.choices.is_empty(): return
		if game.mode == "dialogue": await tap(KEY_E)

func pick(kind: String) -> bool:
	var i: int = game.dialogue.choices.map(func(o): return o.get("kind", "")).find(kind)
	if i < 0: return false
	await tap(game.dialogue.key_for(i))
	return true

func leave() -> void:
	for n in 6:
		if game.mode == "explore": return
		await tap(KEY_ESCAPE); await frames(6)

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge", "workshop", "fountain", "home", "dock"]: s.quests[q] = {"status": "done", "progress": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen", "workshopDone", "fountainRestored", "boatReady"]: s.flags[fl] = true
	s.tutorial.on = false; game.hud.apply_reveals()
	for b in ["counter", "hedge", "flowerBed", "lamp", "bench"]:
		if not s.blueprints.has(b): s.blueprints.append(b)
	s.inventory.merge({"coins": 300, "wood": 60, "stone": 30, "flowers": 20, "crystal": 10, "fruit": 6}, true)
	s.time.day = 4
	s.time.minute = 10 * 60.0
	game.render_resources()
	for a in game.npcs.values(): a.teleport_home()
	game.game_event.connect(func(type, data): events.append({"type": type, "data": data}))
	game.game_event.connect(func(type, data): if type == "paper": papers.append(data))
	await frames(10)

	var hearts0 := int(s.relationships.get("fern", {}).get("hearts", 0))
	var gate := Tastes.near_pos("fern")
	var hedge := put_near("hedge", gate + Vector2(0, -1.5))
	await frames(4)
	var liked: Array = of("taste").filter(func(e): return e.data.npc == "fern")
	check("a1", "A hedge by Gigia's gate pleases her: a heart and her remark", not hedge.is_empty() and liked.size() == 1 and int(s.relationships.get("fern", {}).get("hearts", 0)) == hearts0 + 1,
		"%s, hearts %d→%d" % [str(liked.map(func(e): return e.data.line)), hearts0, int(s.relationships.get("fern", {}).get("hearts", 0))])
	await tap(KEY_I); await frames(8)
	var tl: Node = game.panels.find_child("taste_fern", true, false)
	await shot("bag-knows-gigias-taste")
	check("a2", "From then on the bag lists what Gigia likes", tl != null and String(tl.text).contains("hedges"), String(tl.text) if tl else "no line")
	await leave()

	var piazza := Needs.hangout(Needs.hangouts(), "piazza")
	var pc := Vector2(float(piazza.x), float(piazza.z))
	var c1 := put_near("counter", pc, func(p): return Needs.inside(p, piazza))
	var c2 := put_near("counter", Vector2(-18.0, 4.0))
	var door := Tastes.near_pos("bram")
	var lamps: Array = []
	for n in 2:
		var lp := put_near("lamp", door + Vector2(1.5, 1.5), func(p): return Needs.center(p).distance_to(door) < 5.0)
		if not lp.is_empty(): lamps.append(lp)
	var bench := put_near("bench", door + Vector2(2.0, 2.0), func(p): return Needs.center(p).distance_to(door) < 5.0)
	note("counters %s %s, lamps %d, bench %s" % [str(c1), str(c2), lamps.size(), str(bench)])

	game.shot_cfg["inauguration"] = "play"
	var day := int(s.time.day)
	var slept := await sleep_night()
	var last: Dictionary = game.ceremony.last
	var elio: Array = last.get("reactions", []).filter(func(r): return r.npc == "bram")
	check("a3", "At the evening's opening of the lamps by his door, Elio cheers them for his own taste", slept and last.get("played", false) and not elio.is_empty() and elio[0].get("taste", false) and String(elio[0].line).contains("lamp"),
		"%s: %s" % [last.get("what", ""), str(elio)])
	var paper: Dictionary = papers[-1] if not papers.is_empty() else {}
	check("a4", "Day 5's paper announces market day, counting the two stalls", int(s.time.day) == 5 and paper.get("notes", []).any(func(n): return String(n).contains("Market day") and String(n).contains("2 stalls")), str(paper.get("notes", [])))
	await tap(KEY_P); await frames(8)
	var album: Node = game.panels.find_child("openings", true, false)
	var album_text := ""
	if album: for l in album.find_children("*", "Label", true, false): album_text += l.text + " | "
	await shot("album-of-openings")
	check("a5", "The approval screen keeps an album of openings", album_text.contains("Day 4") and album_text.contains("lamp"), album_text)
	await leave()

	s.time.minute = 8.5 * 60.0
	await frames(6)
	var at: Dictionary = Market.record(s).get("at", {})
	var placed_ok := true
	for id in at:
		var a = game.npcs[id]
		var stall: Dictionary = game._find_pl(int(at[id]))
		if not a.held or Vector2(a.pos.x, a.pos.z).distance_to(Needs.center(stall)) > 2.6: placed_ok = false
	check("a6", "At eight the sellers stand at the counters you built, one each", at.size() == 2 and at.has("fern") and at.has("mabel") and placed_ok, str(at))
	await choices_up("fern")
	var label: bool = game.dialogue.choices.any(func(c): return String(c.label).contains("Market stall"))
	await pick("shop")
	for n in 40:
		await frames(4)
		if game.panels.current == "shop": break
		if game.mode == "dialogue" and game.dialogue.choices.is_empty(): await tap(KEY_E)
	await frames(10)
	await shot("gigias-market-stall")
	var pumpkin: bool = Shop.stock(s, "fern").any(func(e): return e.kind == "items" and e.items.has("pumpkin"))
	check("a7", "Gigia's stall says market prices, pays half as much again for hazelnuts and sells pumpkins", label and game.panels.current == "shop" and Shop.sell_price("fern", "fruit", s) == int(ceil(Shop.def("fern").buys.fruit * float(Market.cfg().buys))) and pumpkin,
		"label %s, panel %s, fruit %d" % [label, game.panels.current, Shop.sell_price("fern", "fruit", s)])
	await leave()
	s.time.minute = 19.5 * 60.0
	await frames(6)
	check("a8", "At seven in the evening the market packs up and the sellers go home", game.market_held.is_empty() and not game.npcs.fern.held and not game.npcs.mabel.held, "")

	var built := 0
	for id in ["flowerBed", "flowerBed", "lamp", "lamp"]:
		if not put_near(id, pc, func(p): return Needs.inside(p, piazza)).is_empty(): built += 1
	await frames(5)
	s.time.minute = 20.5 * 60.0
	game.player.teleport(pc.x + 4.0, pc.y + 4.0, PI * 1.25); game.cam.snap()
	await frames(10)
	var festa: bool = game.festa_now()
	var song := String(game.audio.want_song) if game.audio else "(no audio)"
	check("a9", "At dusk, with the piazza fully lively, the festa plays", built == 4 and Visits.level(game.village_score, "piazza") == 3 and festa and (game.audio == null or song == "hearthglow_festa"), "level %d, festa %s, song %s" % [Visits.level(game.village_score, "piazza"), festa, song])
