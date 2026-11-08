extends RefCounted
var t
var statics: Array
var uid := 800

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

func _cells(list: Array, h: Dictionary) -> Array:
	var w := WalkWorld.new(statics)
	w.surfaces = BuildGrid.surfaces_for(list)
	return Needs.reach_cells(w, h)

func _bench_with_room(list: Array, h: Dictionary) -> Dictionary:
	var c := Vector2(float(h.x), float(h.z))
	var cands: Array = []
	for di in range(-3, 4):
		for dk in range(-3, 4): cands.append(Vector2(floor(c.x) + di, floor(c.y) + dk))
	cands.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	for cand in cands:
		var trial := list.duplicate()
		var b := _put(trial, "bench", cand.x, cand.y)
		if b.is_empty() or not Needs.inside(b, h): continue
		if Visits.use_spot(b, "seat", _cells(trial, h)).get("ok", false):
			list.append(b)
			return b
	return {}

func test_liveliness_rises_with_needs_and_charm():
	var v := {"needs": [{"hangout": "piazza", "met": true}, {"hangout": "piazza", "met": true}, {"hangout": "piazza", "met": false}, {"hangout": "bakery", "met": true}], "charm": [{"hangout": "piazza", "points": 4}, {"hangout": "bakery", "points": 0}]}
	t.eq(Visits.level(v, "piazza"), 3, "two needs met and four charm make the piazza fully lively")
	t.eq(Visits.level(v, "bakery"), 1, "one need met is a start")
	t.eq(Visits.level(v, "church"), 0, "nothing there, nothing lively")

func test_a_bench_with_a_clear_front_is_sat_on():
	var h := Needs.hangout(Needs.hangouts(), "bakery")
	var list: Array = []
	var bench := _bench_with_room(list, h)
	t.ok(not bench.is_empty(), "a bench with room in front fits outside the bakery")
	var spot := Visits.use_spot(bench, "seat", _cells(list, h))
	t.ok(spot.ok and spot.pose == "sit", "a villager sits on it")
	var at := NapGags.seat_spot(bench)
	t.ok(Vector2(at.x, at.z).distance_to(spot.at) < 0.01 and absf(float(spot.y) - at.y) < 0.01, "on the seat itself")
	t.ok(spot.approach.distance_to(Visits.center(bench) + Visits.forward(bench) * 0.85) < 0.6, "coming up to it from the front")

func test_a_bench_facing_a_wall_counts_but_gets_a_stare():
	var h := Needs.hangout(Needs.hangouts(), "bakery")
	var list: Array = []
	var bench := _bench_with_room(list, h)
	var f := Visits.forward(bench)
	var front_k: float = float(bench.k) + (1.0 if f.y > 0.5 else (-1.0 if f.y < -0.5 else 0.0))
	var front_i: float = float(bench.i) + (1.0 if f.x > 0.5 else (-1.0 if f.x < -0.5 else 0.0))
	var blocks := [_put(list, "stoneBlock", front_i, front_k), _put(list, "stoneBlock", front_i + absf(f.y), front_k + absf(f.x))]
	t.ok(blocks.all(func(b): return not b.is_empty()), "stone blocks right in front of it")
	var cells := _cells(list, h)
	t.ok(Needs.reachable(bench, "seat", cells), "you can still walk up to its side, so the need is met")
	var spot := Visits.use_spot(bench, "seat", cells)
	t.ok(not spot.ok and spot.get("stare", false), "but nobody can sit facing a wall: they stare at it")

func test_a_chair_on_a_stack_gets_a_stare():
	var h := Needs.hangout(Needs.hangouts(), "bakery")
	var list: Array = []
	var base := {}
	for di in range(-2, 3):
		base = _put(list, "stoneBlock", floor(float(h.x)) + di, floor(float(h.z)) + 1.0)
		if not base.is_empty(): break
	var top := _put(list, "stoneBlock", base.i, base.k)
	var chair := _put(list, "chair", base.i, base.k)
	t.ok(not chair.is_empty() and float(chair.y) > float(base.y) + 1.5, "a chair two blocks up")
	var cells := _cells(list, h)
	var spot := Visits.use_spot(chair, "seat", cells)
	t.ok(not spot.ok and spot.get("stare", false), "is something to stare at, not to sit on")
	var opts := Visits.options(Needs.hangouts(), list, {"bakery": cells}, {})
	t.ok(opts.any(func(o): return int(o.uid) == int(chair.uid) and not o.use), "and it's on the list of things to go and stare at")

func test_picking_where_to_go():
	var hs := Needs.hangouts()
	var v := {"needs": [{"hangout": "piazza", "met": true}, {"hangout": "piazza", "met": true}, {"hangout": "bakery", "met": true}], "charm": [{"hangout": "piazza", "points": 5}, {"hangout": "bakery", "points": 0}]}
	var opts := [{"hangout": "bakery", "uid": 1, "kind": "seat", "use": true, "spot": {}}, {"hangout": "piazza", "uid": 2, "kind": "stall", "use": true, "spot": {}}, {"hangout": "piazza", "uid": 3, "kind": "seat", "use": false, "spot": {}}]
	var at_dusk := 0
	for i in 20:
		if String(Visits.pick(opts, "captain", hs, v, {}, i / 20.0, true).hangout) == "piazza": at_dusk += 1
	t.ok(at_dusk >= 18, "at dusk, with the piazza fully lively, nearly everyone goes there (%d of 20)" % at_dusk)
	var mabel := 0
	for i in 20:
		if String(Visits.pick(opts, "mabel", hs, {"needs": [], "charm": []}, {}, i / 20.0, false).hangout) == "bakery": mabel += 1
	t.ok(mabel > 7, "Ornella prefers her own bakery door (%d of 20)" % mabel)
	t.ok(Visits.pick(opts, "fern", hs, v, {1: true, 2: true}, 0.1, false).uid == 3, "with the seats and counter taken, only the stare is left")
	t.eq(Visits.pick([], "fern", hs, v, {}, 0.5, false), {}, "nothing built, nowhere to go")

func test_the_path_to_a_seat_stays_on_walkable_ground():
	var h := Needs.hangout(Needs.hangouts(), "bakery")
	var list: Array = []
	var bench := _bench_with_room(list, h)
	var cells := _cells(list, h)
	var spot := Visits.use_spot(bench, "seat", cells)
	var path := Visits.path(cells, h, Vector2(float(h.x) - 4.0, float(h.z) + 3.0), spot.approach)
	t.ok(path.size() >= 2 and path[-1].distance_to(spot.approach) < 0.3, "a path to the seat's front (%d steps)" % path.size())
	var have := {}
	for c in cells: have[Visits.grid(h, Vector2(c.x, c.z))] = true
	var ok := true
	for i in path.size():
		if not have.has(Visits.grid(h, path[i])): ok = false
		if i > 0 and absf(path[i].distance_to(path[i - 1]) - Needs.STEP) > 0.01: ok = false
	t.ok(ok, "every step is half a metre, on ground a villager can stand on")

func test_visit_settings():
	var v: Dictionary = Data.needs.get("visits", {})
	for k in ["every", "stay", "dusk_stay", "first"]: t.ok(v.has(k) and float(v[k][0]) < float(v[k][1]), "visits.%s is a range" % k)
	t.eq(Data.needs.get("liveliness", []).size(), 3, "three steps of liveliness")

func test_a_chair_pulled_up_to_a_table_is_sat_on_from_the_side():
	var h := Needs.hangout(Needs.hangouts(), "bakery")
	var c := Vector2(float(h.x), float(h.z))
	var cands: Array = []
	for di in range(-3, 4):
		for dk in range(-3, 4): cands.append(Vector2(floor(c.x) + di, floor(c.y) + dk))
	cands.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	var list: Array = []
	var chair := {}
	for cand in cands:
		var trial: Array = []
		var ch := _put(trial, "chair", cand.x, cand.y, 0)
		if ch.is_empty() or not Needs.inside(ch, h): continue
		var f := Visits.forward(ch)
		var tb := _put(trial, "table", cand.x + roundf(f.x), cand.y + roundf(f.y), 0)
		if tb.is_empty(): continue
		var side_room := _cells(trial, h).any(func(p): return Vector2(p.x, p.z).distance_to(Visits.center(ch) + Vector2(f.y, f.x) * 0.85) < 0.5 or Vector2(p.x, p.z).distance_to(Visits.center(ch) - Vector2(f.y, f.x) * 0.85) < 0.5)
		if not side_room: continue
		list = trial; chair = ch
		break
	t.ok(not chair.is_empty(), "a chair with a table in front of it at the bakery")
	if chair.is_empty(): return
	var cells := _cells(list, h)
	var spot := Visits.use_spot(chair, "seat", cells, list)
	t.ok(spot.get("ok", false), "someone can sit on it")
	if spot.get("ok", false):
		t.ok(spot.approach.distance_to(Visits.center(chair)) < 1.3 and spot.approach.distance_to(Visits.center(chair) + Visits.forward(chair) * 0.85) > 0.4, "stepping in from beside it, not through the table (%s)" % spot.approach)
	var opts := Visits.options(Needs.hangouts(), list, {"bakery": cells}, {})
	t.ok(opts.any(func(o): return int(o.uid) == int(chair.uid) and o.use), "so villagers come to sit there, not to stare")
