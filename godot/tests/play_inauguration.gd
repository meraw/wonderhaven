extends "res://tests/full_base.gd"

var events: Array = []
var papers: Array = []
var said: Array = []

func cands(h: Dictionary) -> Array:
	var c := Vector2(float(h.x), float(h.z))
	var out: Array = []
	for di in range(-4, 5):
		for dk in range(-4, 5): out.append(Vector2(floor(c.x) + di, floor(c.y) + dk))
	out.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	return out

func put(id: String, i: float, k: float) -> Dictionary:
	var zone := BuildGrid.zone_at(game.placement_ctx().zones, i, k)
	var pl := {"uid": int(game.state.next_uid), "id": id, "i": i, "k": k, "r": 0, "y": BuildGrid.suggest_bottom(id, i, k, 0, 10.0, game.state.placements, zone)}
	game.state.next_uid = int(pl.uid) + 1
	return pl if game.commit_place(pl, false, false).ok else {}

func place_where(id: String, h: Dictionary, test: Callable) -> Dictionary:
	for c in cands(h):
		var pl := put(id, c.x, c.y)
		if pl.is_empty(): continue
		if Needs.inside(pl, h) and test.call(pl): return pl
		game.commit_remove(int(pl.uid), false)
	return {}

func usable(pl: Dictionary) -> bool: return game.visit_opts.any(func(o): return int(o.uid) == int(pl.uid) and o.use)

func of(type: String) -> Array: return events.filter(func(e): return e.type == type)

func start_night() -> bool:
	var p: Vector3 = game.player.pos
	var benches: Array = Data.layout.features.filter(func(f): return f.kind == "bench")
	benches.sort_custom(func(a, b): return Vector2(a.x - p.x, a.z - p.z).length() < Vector2(b.x - p.x, b.z - p.z).length())
	for f in benches:
		if not await walk_to(float(f.x), float(f.z) + 1.6, 0.8): continue
		if not await face_and_press(String(f.id), float(f.x), float(f.z)): continue
		await frames(6)
		var b := game.panels.find_child("wake_tomorrow", true, false) as Button
		if b == null: continue
		await click(b.get_global_rect().get_center())
		return true
	note("found no bench to sleep on")
	return false

func ceremony_started() -> bool:
	for n in 200:
		if game.ceremony.playing: return true
		await frames(1)
	return false

func listen(until: Callable, most: int) -> bool:
	for n in most:
		if game.ceremony.caption and game.ceremony.caption.visible:
			var line: String = game.ceremony.caption_text.text
			if not said.has(line): said.append(line)
		if until.call(): return true
		await frames(1)
	return false

func night_over(day: int) -> bool:
	for n in 600:
		await frames(2)
		if game.mode == "explore" and int(game.state.time.day) > day and not game.ceremony.playing: break
	await frames(20)
	return int(game.state.time.day) > day

func held_near(c: Vector2, r: float) -> Array:
	return game.npcs.values().filter(func(a): return a.held and Vector2(a.pos.x - c.x, a.pos.z - c.y).length() < r)

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}, "done": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen"]: s.flags[fl] = true
	s.tutorial = Tutorial.new_state(false, true); game.hud.apply_reveals()
	s.time.minute = 10 * 60.0
	game.game_event.connect(func(type, data): events.append({"type": type, "data": data}))
	game.game_event.connect(func(type, data): if type == "paper": papers.append(data))
	await frames(10)
	var hs := Needs.hangouts()
	var day := int(s.time.day)
	var slept: bool = await start_night()
	if slept: slept = await night_over(day)
	check("i1", "A day with nothing built ends without a ceremony", slept and of("inauguration_start").is_empty() and of("inauguration").is_empty(), "day %d" % int(s.time.day))

	game.shot_cfg["inauguration"] = "play"
	var bakery := Needs.hangout(hs, "bakery")
	var bench := place_where("bench", bakery, usable)
	var bed := place_where("flowerBed", bakery, func(p): return usable(bench))
	var lone := place_where("stoneBlock", Needs.hangout(hs, "piazza"), func(p): return true)
	note("built bench %s, flower bed %s, lone block %s" % [str(bench), str(bed), str(lone)])
	var hearts_before := int(s.relationships.get("mabel", {}).get("hearts", 0))
	game.hud.clear_tips()
	day = int(s.time.day)
	var started: bool = await start_night()
	if started: started = await ceremony_started()
	await frames(3)
	var dusk := WorkDay.held(s.time, WorkDay.def(Data.island))
	check("i2", "Ending the day after building opens what you built, at dusk, with the camera cut to it", started and dusk and not game.cam.cinema.is_empty() and not game.hud.visible, "%s, %s" % [Clock.text(s.time), str(game.cam.cinema)])
	var c := Visits.center(bench) if not bench.is_empty() else Vector2.ZERO
	var sindaco = game.npcs.get("percival")
	var crowd := held_near(c, 7.5).filter(func(a): return a != sindaco)
	var present: int = game.npcs.values().filter(func(a): return a.present and a != sindaco).size()
	check("i3", "Everyone is gathered round the bench, the Sindaco in front of it", sindaco != null and sindaco.held and Vector2(sindaco.pos.x - c.x, sindaco.pos.z - c.y).length() < 4.5 and crowd.size() >= mini(4, present),
		"%d of %d villagers round it" % [crowd.size(), present])
	await listen(func(): return said.size() >= 1, 200)
	await frames(6)
	await shot("speech")
	await listen(func(): return not of("ribbon_cut").is_empty(), 400)
	var whole := " / ".join(said)
	check("i4", "The Sindaco says what was built and where, which complaint it answers, and takes the credit", said.size() >= 3 and whole.contains("outside the bakery") and whole.contains("bench") and whole.contains("Nowhere to sit outside the bakery"), whole)
	await frames(10)
	await shot("ribbon-cut")
	var rib: Node3D = game.ceremony.ribbon
	var cut: bool = rib != null and absf(rib.get_node("half_l").rotation.z) > 1.0 and absf(rib.get_node("half_r").rotation.z) > 1.0
	var mabel = game.npcs.get("mabel")
	var thanks: bool = mabel != null and mabel.held and mabel.character.get_node_or_null("say") != null
	check("i5", "The ribbon is cut, the crowd cheers and Ornella thanks you", cut and thanks, "ribbon cut %s, Ornella says '%s'" % [cut, mabel.character.get_node("say").text if thanks else "-"])
	var card_ok := false
	for n in 200:
		var cn: Node = game.ceremony.ui.find_child("grade", true, false) if game.ceremony.ui else null
		if cn: card_ok = String(cn.text).begins_with("Voto"); break
		await frames(1)
	await frames(5)
	await shot("grade-card")
	var appr: Node = game.ceremony.ui.find_child("approval", true, false) if game.ceremony.ui else null
	check("i6", "The approval for the day is counted and the build gets a mark out of ten", card_ok and appr != null and String(appr.text).contains("today"), String(appr.text) if appr else "no approval line")
	var over := await night_over(day)
	var last: Dictionary = game.ceremony.last
	var paper: Dictionary = papers[-1] if not papers.is_empty() else {}
	await shot("paper-opened")
	var hearts_after := int(s.relationships.get("mabel", {}).get("hearts", 0))
	check("i7", "Next morning you're on your bench, Ornella likes you more, and the paper leads with the opening and its mark", over and not game.sitting.is_empty() and hearts_after == hearts_before + 1 and String(paper.get("headline", "")).contains("outside the bakery") and paper.get("notes", []).any(func(n): return String(n).contains(String(last.get("grade", "?")))),
		"hearts %d→%d, %s / %s" % [hearts_before, hearts_after, paper.get("headline", ""), str(paper.get("notes", []))])
	check("i8", "The stone block across the village wasn't part of it, and nobody is left standing in place", last.get("played", false) and not last.get("skipped", true) and not last.get("uids", []).has(int(lone.get("uid", -1))) and not game.npcs.values().any(func(a): return a.held),
		"opened %s" % str(last.get("uids", [])))

	said.clear()
	var church := Needs.hangout(hs, "church")
	var base := place_where("stoneBlock", church, func(p): return true)
	var top := put("stoneBlock", float(base.get("i", 0)), float(base.get("k", 0))) if not base.is_empty() else {}
	var chair := put("chair", float(base.get("i", 0)), float(base.get("k", 0))) if not top.is_empty() else {}
	day = int(s.time.day)
	var cuts := of("ribbon_cut").size()
	var started2: bool = await start_night()
	if started2: started2 = await ceremony_started()
	await listen(func(): return of("ribbon_cut").size() > cuts, 600)
	await frames(12)
	await shot("puzzled-crowd")
	var c2 := Visits.center(chair) if not chair.is_empty() else Vector2.ZERO
	var shrugs: Array = held_near(c2, 8.0).filter(func(a): return a != sindaco)
	var all_marked: bool = not shrugs.is_empty() and shrugs.all(func(a): return a.stare_mark.visible)
	await night_over(day)
	var last2: Dictionary = game.ceremony.last
	check("i9", "A chair two blocks up gets its ceremony too, but the crowd shrugs with question marks and nobody's heart is won", started2 and all_marked and not last2.get("reactions", []).any(func(r): return r.heart) and " ".join(said).contains("church steps"),
		"%d shrugging; %s" % [shrugs.size(), " / ".join(said)])

	var lamp := place_where("lamp", Needs.hangout(hs, "piazza"), func(p): return true)
	day = int(s.time.day)
	var started3: bool = await start_night()
	if started3: started3 = await ceremony_started()
	await frames(10)
	await tap(KEY_ESCAPE)
	var gone := -1
	for n in 40:
		if not game.ceremony.playing: gone = n; break
		await frames(1)
	await night_over(day)
	var last3: Dictionary = game.ceremony.last
	var paper3: Dictionary = papers[-1] if not papers.is_empty() else {}
	check("i10", "Esc skips the ceremony at once, and the paper still reports it", started3 and gone >= 0 and gone < 15 and last3.get("skipped", false) and String(paper3.get("headline", "")).contains("lamp"),
		"gone after %d frames; %s" % [gone, paper3.get("headline", "")])

	game.settings["inaugurations"] = false
	var hedge := place_where("hedge", Needs.hangout(hs, "piazza"), func(p): return true)
	var starts_before := of("inauguration_start").size()
	day = int(s.time.day)
	var slept5: bool = await start_night()
	if slept5: slept5 = await night_over(day)
	var last5: Dictionary = game.ceremony.last
	game.settings["inaugurations"] = true
	check("i11", "With inaugurations turned off in the settings there's no ceremony, but the build is still reported", slept5 and of("inauguration_start").size() == starts_before and not last5.get("played", true) and String(last5.get("what", "")).contains("hedge"),
		str(last5.get("what", "")))
