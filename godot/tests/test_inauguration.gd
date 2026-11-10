extends RefCounted
var t
var statics: Array
var uid := 900

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

func _ctx(list: Array) -> Dictionary:
	return {"placements": list, "zones": Data.layout.zones.filter(func(z): return not z.has("unlock")), "statics": statics, "bodies": []}

func _put(list: Array, id: String, i: float, k: float, r: int = 0) -> Dictionary:
	var z := BuildGrid.zone_at(_ctx(list).zones, i, k)
	var pl := {"uid": uid, "id": id, "i": i, "k": k, "r": r, "y": BuildGrid.suggest_bottom(id, i, k, r, 10.0, list, z)}
	uid += 1
	if BuildGrid.validate_placement(pl, _ctx(list)).ok:
		list.append(pl)
		return pl
	return {}

func _walk(list: Array) -> WalkWorld:
	var w := WalkWorld.new(statics)
	w.surfaces = BuildGrid.surfaces_for(list)
	return w

func _cells(list: Array) -> Dictionary:
	var w := _walk(list)
	var out := {}
	for h in Needs.hangouts(): out[String(h.id)] = Needs.reach_cells(w, h)
	return out

func _near(list: Array, id: String, h: Dictionary, test: Callable = func(_l, _p): return true) -> Dictionary:
	var c := Vector2(float(h.x), float(h.z))
	var cands: Array = []
	for di in range(-3, 4):
		for dk in range(-3, 4): cands.append(Vector2(floor(c.x) + di, floor(c.y) + dk))
	cands.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	for cand in cands:
		var trial := list.duplicate()
		var p := _put(trial, id, cand.x, cand.y)
		if p.is_empty() or not Needs.inside(p, h) or not test.call(trial, p): continue
		list.append(p)
		return p
	return {}

func _scene(list: Array) -> Dictionary:
	var hs := Needs.hangouts()
	var cells := _cells(list)
	return {"hs": hs, "village": Needs.village(hs, list, cells, {}), "opts": Visits.options(hs, list, cells, {})}

func _usable(trial: Array, p: Dictionary) -> bool:
	var s := _scene(trial)
	return s.opts.any(func(o): return int(o.uid) == int(p.uid) and o.use)

func test_naming_what_was_built():
	var c := Inauguration.cfg()
	t.eq(Inauguration.what(["bench"], c), "a bench", "one bench")
	t.eq(Inauguration.what(["lamp", "bench", "lamp"], c), "two lamps and a bench", "the most of a kind first")
	t.eq(Inauguration.what(["stairs"], c), "a flight of stairs", "stairs have their own words")
	t.eq(Inauguration.what(["poweredLamp"], c), "an electric lamp", "an, before a vowel")
	t.eq(Inauguration.what(["bench", "bench"], c), "two benches", "benches")
	t.eq(Inauguration.what(["hedge", "lamp", "bench", "chair", "chair", "table"], c), "two chairs, a hedge, a lamp and 2 other pieces", "only three kinds by name")

func test_todays_pieces_are_remembered():
	var s := GameState.new_game("Tester")
	t.eq(Inauguration.pending(s, [{"uid": 5}]), [], "nothing put up yet today")
	Inauguration.placed(s, 5); Inauguration.placed(s, 6); Inauguration.placed(s, 5)
	Inauguration.removed(s, 6)
	var list := [{"uid": 5.0}, {"uid": 6}, {"uid": 7}]
	t.ok(Inauguration.pending(s, list).size() == 1 and int(Inauguration.pending(s, list)[0].uid) == 5, "the piece still standing, not the one taken away")
	var back := SaveSystem.deserialize(SaveSystem.serialize(s))
	t.eq(Inauguration.pending(back, list).size(), 1, "remembered across a save")
	t.ok(Inauguration.on() and Inauguration.speaker() == "percival", "Monteforchetta has a work day and the Sindaco to open things")

func test_a_bench_at_the_bakery_is_opened_with_a_speech():
	var hs := Needs.hangouts()
	var bakery := Needs.hangout(hs, "bakery")
	var list: Array = []
	var bench := _near(list, "bench", bakery, _usable)
	var bed := _near(list, "flowerBed", bakery)
	var far := _put(list, "stoneBlock", 2.0, 8.0)
	t.ok(not bench.is_empty() and not bed.is_empty() and not far.is_empty(), "a bench and a flower bed at the bakery, a stone block across the village")
	var c := Inauguration.cfg()
	var s := _scene(list)
	var group := Inauguration.subject(list, s.village, c)
	t.ok(group.size() == 2 and not group.any(func(p): return int(p.uid) == int(far.uid)), "the bakery pieces are what gets opened")
	var f := Inauguration.facts(group, hs, s.village, s.opts, c)
	t.ok(f.hangout == "bakery" and f.place == "outside the bakery" and f.who == "mabel", "at the bakery door, Ornella's spot: %s" % str(f))
	t.ok(f.needs.has("bakery:seat") and f.usable >= 1, "it gives the bakery somewhere to sit")
	var lines := Inauguration.speech(f, hs, c, [0.0, 0.0, 0.0])
	t.ok(lines.size() == 3 and String(lines[0]).contains("outside the bakery") and String(lines[0]).contains("a bench"), "the Sindaco says what and where: %s" % lines[0])
	t.ok(String(lines[1]).contains("outside the bakery.") and Inauguration.body_kind(f, c) == "need", "and which complaint it answers: %s" % lines[1])
	t.ok(String(lines[2]).contains("Geometra"), "and takes the credit: %s" % lines[2])
	var g := Inauguration.grade(f, c)
	t.ok(g >= 8.0 and Inauguration.grade_text(g, c).ends_with("/10"), "a good mark: %s" % Inauguration.grade_text(g, c))
	var r := Inauguration.reactions(f, ["fern", "mabel", "captain"], c, 0.3)
	var mabel: Dictionary = r.filter(func(x): return x.npc == "mabel")[0]
	t.ok(mabel.heart and mabel.line != "" and mabel.anim == "celebrate", "Ornella thanks you and likes you more")
	t.ok(r.all(func(x): return x.mood == "cheer") and r.filter(func(x): return x.line != "").size() == 2, "everyone cheers, two of them say something")

func test_a_chair_on_a_stack_is_called_art():
	var hs := Needs.hangouts()
	var bakery := Needs.hangout(hs, "bakery")
	var list: Array = []
	var base := {}
	for di in range(-2, 3):
		base = _put(list, "stoneBlock", floor(float(bakery.x)) + di, floor(float(bakery.z)) + 1.0)
		if not base.is_empty(): break
	var top := _put(list, "stoneBlock", base.i, base.k)
	var chair := _put(list, "chair", base.i, base.k)
	t.ok(not chair.is_empty() and float(chair.y) > float(base.y) + 1.5, "a chair two blocks up outside the bakery")
	var c := Inauguration.cfg()
	var s := _scene(list)
	var f := Inauguration.facts(Inauguration.subject(list, s.village, c), hs, s.village, s.opts, c)
	t.ok(f.n == 3 and f.stares == 1 and f.usable == 0 and f.needs.is_empty(), "nobody can sit on it: %s" % str(f))
	t.eq(Inauguration.body_kind(f, c), "art", "so the Sindaco calls it art")
	var r := Inauguration.reactions(f, ["fern", "mabel"], c, 0.5)
	t.ok(r.all(func(x): return x.anim == "shrug" and not x.heart), "the crowd shrugs, and nobody's heart is won")
	t.eq(Inauguration.grade_text(Inauguration.grade(f, c), c), "6½/10", "it still passes")
	var steps := {"n": 3, "needs": ["church:seat"], "usable": 0, "stares": 1, "kinds": 2, "colours": 0, "who": "", "hangout": "church", "perch": 2.0}
	t.ok(Inauguration.body_kind(steps, c) == "need" and Inauguration.mood(steps) == "puzzled", "a seat that counts but nobody can sit on: the Sindaco boasts, the crowd shrugs")

func test_the_speaker_opening_his_own_steps():
	var hs := Needs.hangouts()
	var list: Array = []
	var lamp := _near(list, "lamp", Needs.hangout(hs, "castle"))
	t.ok(not lamp.is_empty(), "a lamp on the castle steps")
	var c := Inauguration.cfg()
	var s := _scene(list)
	var f := Inauguration.facts([lamp], hs, s.village, s.opts, c)
	t.eq(Inauguration.body_kind(f, c), "own", "the Sindaco notices whose steps they are")
	t.ok(not Inauguration.reactions(f, ["mabel", "fern"], c, 0.2).any(func(x): return x.heart), "and nobody else gets a thank-you heart")

func test_grades():
	var c := Inauguration.cfg()
	var lone := {"needs": [], "kinds": 1, "usable": 0, "colours": 0}
	t.eq(Inauguration.grade_text(Inauguration.grade(lone, c), c), "6/10", "a lone stone block scrapes a pass")
	var piazza := {"needs": ["piazza:green", "piazza:light", "piazza:stall"], "kinds": 3, "usable": 3, "colours": 0}
	t.eq(Inauguration.grade_text(Inauguration.grade(piazza, c), c), "10 e lode", "a piazza with everything it wanted gets top marks")
	var painted := {"needs": ["bakery:seat"], "kinds": 1, "usable": 1, "colours": 1}
	t.eq(Inauguration.grade(painted, c), 8.0, "a painted bench people sit on")

func test_everyone_has_a_place_to_stand():
	var hs := Needs.hangouts()
	var bakery := Needs.hangout(hs, "bakery")
	var list: Array = []
	_near(list, "bench", bakery, _usable)
	_near(list, "flowerBed", bakery)
	var w := _walk(list)
	var st := Inauguration.stage(w, list, 5)
	t.ok(not st.is_empty(), "there's room for a ceremony at the bakery")
	var people: Array = [st.speaker, st.player] + st.crowd
	t.ok(st.player != Vector3.INF and st.crowd.size() == 5, "the Sindaco, you and five villagers (%d)" % st.crowd.size())
	var ok := true
	for i in people.size():
		var p: Vector3 = people[i]
		if w.can_stand(p.x, p.z, p.y, 0.32).is_empty(): ok = false
		for j in range(i + 1, people.size()):
			if Vector2(p.x - people[j].x, p.z - people[j].z).length() < 0.79: ok = false
		for pl in list:
			var b := BuildGrid.bounds(pl)
			if p.x > b.minX and p.x < b.maxX and p.z > b.minZ and p.z < b.maxZ: ok = false
	t.ok(ok, "each stands on open ground, apart from the others and clear of the pieces")
	var d := Vector2(sin(st.yaw), cos(st.yaw))
	var cam: Vector3 = st.cams[0]
	t.ok(Vector2(cam.x - st.center.x, cam.z - st.center.z).dot(d) > 4.0, "the camera looks at the Sindaco from the open side")

func test_the_paper_reports_the_inauguration():
	var rec := {"quests": [], "built": 2, "harmony": 5, "opened": {"what": "a bench and a flower bed", "place": "outside the bakery", "grade": "8/10"}}
	var p := MorningPaper.compose(rec, {"day": 4, "harmony": 15}, Data.paper, [], 0.0)
	t.ok(String(p.headline).contains("a bench and a flower bed") and String(p.headline).contains("outside the bakery"), "the headline is the opening: %s" % p.headline)
	t.ok(p.notes.any(func(n): return String(n).contains("8/10")), "with the grade: %s" % str(p.notes))
	var plain := MorningPaper.compose({"quests": [], "built": 2, "harmony": 5}, {"day": 4, "harmony": 5}, Data.paper, [], 0.0)
	t.ok(String(plain.headline).contains("2"), "without one it's the old headline: %s" % plain.headline)

func test_the_crowds_comments_come_one_at_a_time_with_the_thanks_first():
	var reacts := [
		{"npc": "a", "line": "", "heart": false},
		{"npc": "b", "line": "Not bad, for a Geometra.", "heart": false},
		{"npc": "c", "line": "Thank you, it's just what I wanted!", "heart": true},
		{"npc": "d", "line": "", "heart": false}]
	var order := InaugurationScene.speaking_order(reacts)
	t.eq(order.map(func(r): return r.npc), ["c", "b"], "only those with something to say, the one thanking you first")

func test_each_comment_stays_long_enough_to_read():
	t.ok(InaugurationScene.reading_time("Hm.") >= 2.6, "even a short one stays a while")
	var long_line := "Well, I never thought I'd see a bench outside the bakery in my lifetime, and here it is, with a cushion."
	t.ok(InaugurationScene.reading_time(long_line) > 5.0, "a long one stays longer (%.1f s)" % InaugurationScene.reading_time(long_line))
	t.ok(InaugurationScene.reading_time(long_line + long_line) <= 6.0, "but never holds the scene for ever")
