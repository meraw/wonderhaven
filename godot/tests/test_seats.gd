extends RefCounted
var t

func _bench(i: float, k: float, r: int = 0, uid: int = 1) -> Dictionary:
	return {"id": "bench", "i": i, "k": k, "r": r, "y": 0.0, "uid": uid}

func test_a_bench_seats_two_side_by_side_and_a_chair_one():
	var b := _bench(0.0, 0.0)
	var s := Seats.spots(b)
	t.eq(s.size(), 2, "a bench has two places")
	var a: Vector3 = s[0].at
	var c: Vector3 = s[1].at
	t.ok(absf(a.distance_to(c) - 2.0 * Seats.HALF) < 0.01, "a metre apart")
	t.ok(absf(a.z - c.z) < 0.01, "along the bench's length")
	t.ok(absf(a.y - Seats.SEAT_LIFT) < 0.01, "at seat height")
	var mid := NapGags.seat_spot(b)
	t.ok(Vector2((a.x + c.x) / 2.0, (a.z + c.z) / 2.0).distance_to(Vector2(mid.x, mid.z)) < 0.01, "either side of the middle")
	for p in s:
		var ap: Vector2 = p.approach
		t.ok(ap.distance_to(Vector2(p.at.x, p.at.z) + Visits.forward(b) * Seats.APPROACH) < 0.01, "each reached from the front")
		t.ok(absf(float(p.yaw) - (-int(b.r) * PI / 2.0)) < 0.001, "facing the way the bench faces")
	var turned := Seats.spots(_bench(4.0, 4.0, 1))
	t.ok(absf(turned[0].at.x - turned[1].at.x) < 0.01 and absf(turned[0].at.z - turned[1].at.z) > 0.9, "a bench turned a quarter seats them along its new length")
	t.eq(Seats.spots({"id": "chair", "i": 0.0, "k": 0.0, "r": 0, "y": 0.0, "uid": 3}).size(), 1, "a chair has one place")

func test_two_people_never_share_a_place():
	var s := Seats.spots(_bench(0.0, 0.0))
	var left: Vector3 = s[0].at
	var right: Vector3 = s[1].at
	t.eq(Seats.free_spot(s, [], Vector2(left.x - 2.0, left.z)), 0, "an empty bench: the half nearer you")
	t.eq(Seats.free_spot(s, [left], Vector2(left.x - 2.0, left.z)), 1, "someone on that half: the other one")
	t.eq(Seats.free_spot(s, [left, right], Vector2.ZERO), -1, "both taken: no place")
	t.eq(Seats.free_spot(s, [left + Vector3(0, 3.0, 0)], Vector2(left.x - 2.0, left.z)), 0, "someone on the balcony above doesn't count")

func test_a_villager_claims_the_nearest_bench_with_room():
	var near := _bench(2.0, 0.0, 0, 1)
	var far := _bench(5.0, 0.0, 0, 2)
	var list := Seats.entries([near, far, {"id": "fence", "i": 1.0, "k": 1.0, "r": 0, "y": 0.0, "uid": 9}], [])
	t.eq(list.size(), 2, "benches count as seats and a fence doesn't")
	var got := Seats.claim(list, Vector2(0.0, 0.5), [])
	t.eq(String(got.get("key", "")), "pl:1", "the nearer bench")
	t.eq(int(got.get("index", -1)), 1, "taking the far half, so the near one stays free for you")
	var both: Array = list[0].spots.map(func(p): return p.at)
	t.eq(String(Seats.claim(list, Vector2(0.0, 0.5), both).get("key", "")), "pl:2", "the nearer one full: the next")
	t.ok(Seats.claim(list, Vector2(40.0, 40.0), []).is_empty(), "nothing within reach: no bench")

func test_a_layout_bench_is_the_same_seat_as_the_one_you_sit_on():
	Data.use_island("hearthglow")
	var f := {"id": "b", "kind": "bench", "x": 3.0, "z": 4.0, "r": 1}
	var fp := BuildGrid.footprint(Data.piece("bench"), 1)
	var as_world_actions := {"id": "bench", "i": f.x - fp.x / 2.0, "k": f.z - fp.y / 2.0, "r": 1, "y": 0.5}
	t.eq(Seats.key_of(Seats.feature_seat(f, 0.5)), Seats.key_of(as_world_actions), "the seat the prompt hands over is found in the list")
	var list := Seats.entries([], [Seats.feature_seat(f, 0.5)])
	t.eq(list.size(), 1, "the layout's bench is a seat too")

func test_sitting_beside_someone_is_on_the_same_bench():
	var s := Seats.spots(_bench(0.0, 0.0))
	t.ok(Seats.beside(s, s[1].at), "Nonna on the other half")
	t.ok(not Seats.beside(s, s[1].at + Vector3(3.0, 0, 0)), "not someone standing nearby")

func test_nonna_sits_on_her_bench_at_dusk_once_it_is_built():
	Data.use_island("rice_village")
	var def := {}
	for n in Data.npcs_here():
		if String(n.id) == "rice_village_pierina": def = n
	t.ok(not def.is_empty(), "Nonna lives in Casalrana")
	var before := Schedule.activity_at(def, 17.0 * 60.0, {})
	t.ok(String(before.activity) != "sit", "no bench yet: she doesn't sit on thin air by the paddy")
	var after := Schedule.activity_at(def, 17.0 * 60.0, {"rice_village_benchBuilt": true})
	t.eq(String(after.activity), "sit", "with her bench built she sits at dusk")
	t.ok(not def.get("sitLines", []).is_empty(), "and has something to say when you sit with her")
	var p: Array = Data.layout.nav_nodes[String(after.node)]
	var z := Data.zone("rice_village_bench")
	for c in [Vector2(z.minI, z.minK), Vector2(z.maxI, z.minK), Vector2(z.minI, z.maxK), Vector2(z.maxI, z.maxK)]:
		t.ok(Vector2(float(p[0]), float(p[1])).distance_to(c) < Seats.REACH, "a bench anywhere in her corner of the paddy is within her reach (%s)" % str(c))
	Data.use_island("hearthglow")
