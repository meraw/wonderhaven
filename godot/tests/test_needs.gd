extends RefCounted
var t
var statics: Array
var uid := 500

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

func _ctx(list: Array) -> Dictionary:
	return {"placements": list, "zones": Data.layout.zones.filter(func(z): return not z.has("unlock")), "statics": statics, "bodies": []}

func _walk(list: Array) -> WalkWorld:
	var w := WalkWorld.new(statics)
	w.surfaces = BuildGrid.surfaces_for(list)
	return w

func _put(list: Array, id: String, i: float, k: float, r: int = 0, hit: float = 10.0) -> Dictionary:
	var z := BuildGrid.zone_at(_ctx(list).zones, i, k)
	var pl := {"uid": uid, "id": id, "i": i, "k": k, "r": r, "y": BuildGrid.suggest_bottom(id, i, k, r, hit, list, z)}
	uid += 1
	var v := BuildGrid.validate_placement(pl, _ctx(list))
	if v.ok: list.append(pl)
	return pl if v.ok else {}

func _spot(list: Array, id: String, h: Dictionary) -> Dictionary:
	var r := float(h.r)
	for di in range(-int(r), int(r) + 1):
		for dk in range(-int(r), int(r) + 1):
			var probe := {"uid": -1, "id": id, "i": floor(float(h.x)) + di, "k": floor(float(h.z)) + dk, "r": 0, "y": 0.0}
			if not Needs.inside(probe, h): continue
			var got := _put(list, id, probe.i, probe.k)
			if not got.is_empty(): return got
	return {}

func _score(list: Array, lit: Dictionary = {}) -> Dictionary:
	var w := _walk(list)
	var cells := {}
	for h in Needs.hangouts(): cells[String(h.id)] = Needs.reach_cells(w, h)
	return Needs.village(Needs.hangouts(), list, cells, lit)

func _met(v: Dictionary, k: String) -> bool: return Needs.met_keys(v).has(k)

func test_monteforchetta_hangouts_are_sound():
	var hs := Needs.hangouts()
	t.ok(hs.size() >= 5, "%d hangouts" % hs.size())
	var open_zones: Array = Data.layout.zones.filter(func(z): return not z.has("unlock"))
	var w := _walk([])
	for h in hs:
		for kind in h.needs:
			t.ok(not Needs.kind_def(kind).is_empty() and Data.pieces.any(func(p): return p.get("provides", []).has(kind)), "%s: %s is a need some piece meets" % [h.id, kind])
		if h.has("who"): t.ok(not Data.npc(String(h.who)).is_empty(), "%s: %s is a villager" % [h.id, h.who])
		t.ok(not BuildGrid.zone_at(open_zones, floor(float(h.x)), floor(float(h.z))).is_empty(), "%s can be built on from the start" % h.id)
		t.ok(Needs.reach_cells(w, h).size() > 20, "%s: you can walk about in it" % h.id)
	for p in Data.pieces:
		for kind in p.get("provides", []): t.ok(not Needs.kind_def(kind).is_empty(), "%s provides a known need (%s)" % [p.id, kind])

func test_a_bench_you_can_walk_to_meets_the_need():
	var h := Needs.hangout(Needs.hangouts(), "bakery")
	var list: Array = []
	t.ok(not _met(_score(list), "bakery:seat"), "nothing built, nowhere to sit")
	var bench := _spot(list, "bench", h)
	t.ok(not bench.is_empty(), "a bench fits outside the bakery")
	var v := _score(list)
	t.ok(_met(v, "bakery:seat"), "a bench outside the bakery is somewhere to sit")
	t.ok(int(v.points) >= int(Data.needs.points), "and it's worth %d approval (%d with charm)" % [int(Data.needs.points), int(v.points)])
	t.eq(Needs.line(Needs.hangouts(), "bakery:seat"), "Nowhere to sit outside the bakery.", "the paper's line for it")
	t.eq(Needs.line(Needs.hangouts(), "bakery:seat", "met"), "Somewhere to sit outside the bakery", "and the toast's")

func test_a_bench_nobody_can_reach_does_not_count():
	var h := Needs.hangout(Needs.hangouts(), "bakery")
	var list: Array = []
	var base := _spot(list, "stoneBlock", h)
	t.ok(not base.is_empty(), "a stone block outside the bakery")
	var top := _put(list, "stoneBlock", base.i, base.k, 0, 10.0)
	t.ok(not top.is_empty() and float(top.y) > float(base.y) + 0.5, "a second on top of it")
	var bench := _put(list, "chair", base.i, base.k, 0, 10.0)
	t.ok(not bench.is_empty() and float(bench.y) > float(base.y) + 1.5, "a chair up on the stack (%s)" % str(bench))
	t.ok(not _met(_score(list), "bakery:seat"), "a chair two blocks up is nowhere to sit")

func test_shelter_light_and_charm():
	var h := Needs.hangout(Needs.hangouts(), "belvedere")
	var list: Array = []
	var pillar := _spot(list, "pillar", h)
	t.ok(not pillar.is_empty(), "a pillar at the bus stop")
	var roof := {}
	for d in [[0, 0], [-1, 0], [0, -1], [-1, -1]]:
		roof = _put(list, "roof", pillar.i + d[0], pillar.k + d[1], 0, 10.0)
		if not roof.is_empty(): break
	t.ok(not roof.is_empty(), "a roof on it")
	t.ok(_met(_score(list), "belvedere:shelter"), "a roof on a pillar is somewhere to keep dry")
	var lamp := _spot(list, "lamp", h)
	t.ok(not lamp.is_empty() and _met(_score(list), "belvedere:light"), "a lamp lights the bus stop")
	var piazza := Needs.hangout(Needs.hangouts(), "piazza")
	var dark: Array = []
	var pl := _spot(dark, "poweredLamp", piazza)
	t.ok(not pl.is_empty(), "an electric lamp in the piazza")
	t.ok(not _met(_score(dark), "piazza:light"), "unpowered, it doesn't light anything")
	t.ok(_met(_score(dark, {pl.uid: true}), "piazza:light"), "powered and lit, it does")
	t.eq(Needs.charm_points([{"id": "bench"}, {"id": "bench"}, {"id": "bench"}]), 1, "three benches are one bench and a half of charm")
	var varied: Array = ["bench", "chair", "table", "hedge", "flowerBed", "tree", "lamp"].map(func(id): return {"id": id})
	t.eq(Needs.charm_points(varied), int(Data.needs.charm.max), "variety fills the charm, up to its most")
	t.eq(Needs.charm_points([{"id": "bench", "color": "#ff7aa8"}, {"id": "chair", "color": "#6cc4ff"}]), 3, "a splash of colour adds to it")

func _meets(id: String, h: Dictionary, kind: String) -> bool:
	var reach := int(float(h.r)) + 1
	for rot in 4:
		for di in range(-reach, reach + 1):
			for dk in range(-reach, reach + 1):
				var i := floorf(float(h.x)) + di
				var k := floorf(float(h.z)) + dk
				if not Needs.inside({"uid": -1, "id": id, "i": i, "k": k, "r": rot, "y": 0.0}, h): continue
				var list: Array = []
				if kind == "shelter":
					var pillar := _put(list, "pillar", i, k, 0)
					if pillar.is_empty(): continue
					var roof := {}
					for d in [[0, 0], [-1, 0], [0, -1], [-1, -1]]:
						roof = _put(list, id, i + d[0], k + d[1], rot, 10.0)
						if not roof.is_empty(): break
					if roof.is_empty(): continue
				elif _put(list, id, i, k, rot).is_empty(): continue
				var lit := {}
				for pl in list: lit[pl.uid] = true
				if _met(_score(list, lit), Needs.key(h, kind)): return true
	return false

func test_every_need_can_be_met_by_every_piece_that_provides_it():
	var pairs := 0
	for h in Needs.hangouts():
		for kind in h.needs:
			var by: Array = Data.pieces.filter(func(p): return p.get("provides", []).has(kind))
			for p in by:
				pairs += 1
				t.ok(_meets(String(p.id), h, String(kind)), "%s: a %s there, someone can walk up to it, is %s" % [h.id, p.id, Needs.kind_def(kind).get("name", kind)])
	t.ok(pairs >= Needs.hangouts().size() * 2, "%d place, need and piece combinations checked" % pairs)

func test_needs_are_noticed_a_few_at_a_time():
	var s := GameState.new_game("Tester")
	var hs := Needs.hangouts()
	var first := Needs.notice(s, hs, {}, 0.3)
	t.ok(first.size() == int(Data.needs.open_max), "three noticed at once (%s)" % str(first))
	t.ok(first.all(func(k): return Needs.can_build(String(k).get_slice(":", 1), s.blueprints)), "only for pieces you can already build: %s" % str(first))
	t.ok(not first.any(func(k): return String(k).ends_with(":light")), "no lamps yet, so nobody asks for light")
	t.eq(Needs.notice(s, hs, {}, 0.7), [], "with three open, nothing more is noticed")
	var met := {first[0]: true}
	var more := Needs.notice(s, hs, met, 0.5)
	t.ok(more.size() == 1 and not first.has(more[0]), "one met makes room for one more: %s" % str(more))
	var again := GameState.new_game("Tester")
	t.eq(Needs.notice(again, hs, {}, 0.3), first, "the same morning roll picks the same needs")
	var lights := 0
	for i in 10:
		var lit := GameState.new_game("Tester")
		lit.blueprints.append("lamp")
		if Needs.notice(lit, hs, {}, i / 10.0).any(func(k): return String(k).ends_with(":light")): lights += 1
	t.ok(lights > 0, "once you can build lamps, people start asking for light (%d mornings in 10)" % lights)

func test_approval_follows_the_village_but_milestones_stay():
	var s := GameState.new_game("Tester")
	s.harmony = 10; s.approval_best = 10
	var up := Needs.settle(s, 10)
	t.ok(int(s.harmony) == 20 and up.delta == 10 and up.unlocks.any(func(u): return int(u.at) == 15), "10 village points take approval to 20, past the 15 milestone: %s" % str(up))
	var down := Needs.settle(s, 0)
	t.ok(int(s.harmony) == 10 and down.delta == -10 and int(s.approval_best) == 20, "taking the pieces away brings it back to 10, the best stays 20")
	var back := Needs.settle(s, 10)
	t.ok(back.unlocks.is_empty() and int(s.harmony) == 20, "building them again doesn't hand out the milestone twice")
	var raised := Needs.raise(s, 35)
	t.ok(int(s.harmony) == 55 and raised.any(func(u): return int(u.at) == 50), "a request's reward still reaches milestones: %s" % str(raised))
	t.ok(LocationMeter.progress(s, "hearthglow") >= 55.0, "the plot grows with the best approval")
	Needs.settle(s, 0)
	t.ok(LocationMeter.progress(s, "hearthglow") >= 55.0, "and doesn't shrink back when approval dips")
	var back2 := SaveSystem.deserialize(SaveSystem.serialize(s))
	t.ok(int(back2.approval_best) == 55 and int(back2.village_points) == 0, "the best and the village points are saved")

func test_the_paper_leads_with_what_was_noticed():
	var p := MorningPaper.compose({"quests": [], "built": 0, "harmony": 5}, {"day": 3, "harmony": 5, "noticed": ["Nowhere to sit outside the bakery.", "It's dark on the church steps after dusk."], "weather": "rain"}, Data.paper, [], 0.0)
	t.ok(p.notes.size() == 3 and String(p.notes[0]).contains("outside the bakery") and String(p.notes[1]).contains("church steps"), "noticed needs come first: %s" % str(p.notes))
