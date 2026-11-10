extends RefCounted
var t

func _close(a: Vector2, b: Vector2, e: float = 0.001) -> bool: return a.distance_to(b) < e

func _scene() -> Dictionary:
	Data.use_island("rice_village")
	var q := Data.quest("rice_village_nativity")
	for o in q.objectives:
		if o.id == "evening": return o.scene
	return {}

func test_the_nativity_is_staged_in_data_on_its_evening_step():
	var s := _scene()
	t.ok(not s.is_empty(), "the evening step has a scene")
	t.eq(Staging.cast_ids(s).size(), 4, "Silvia, Barba Tista, Matteo and Nonna have parts")
	t.ok(Data.zone(String(s.at.zone)).size() > 0, "it plays at the churchyard you build in")
	var lines: int = Data.quest("rice_village_nativity").objectives.filter(func(o): return o.id == "evening")[0].lines.size()
	for b in s.beats: t.ok(int(b.line) < lines, "beat %d belongs to one of Don Remo's lines" % int(b.line))
	for a in s.actors:
		if a.has("npc"): t.ok(not Data.npc(String(a.npc)).is_empty(), "%s is a villager here" % a.npc)
	Data.use_island("hearthglow")

func test_the_stage_is_the_roof_you_built_or_the_middle_of_the_site():
	var s := _scene()
	var zone := Data.zone("rice_village_churchyard")
	t.ok(_close(Staging.anchor(s, []), Staging.zone_centre(zone)), "nothing built: the middle of the churchyard")
	var roof := {"id": "roof", "i": -15, "k": 0, "r": 0, "y": 2.0}
	var post := {"id": "pillar", "i": -18, "k": 3, "r": 0, "y": 0.42}
	var b := BuildGrid.bounds(roof)
	var mid := Vector2((float(b.minX) + float(b.maxX)) / 2.0, (float(b.minZ) + float(b.maxZ)) / 2.0)
	t.ok(_close(Staging.anchor(s, [post, roof]), mid), "the roof marks the stable, not a post elsewhere")
	var far := {"id": "roof", "i": 30, "k": 30, "r": 0, "y": 0.42}
	t.ok(_close(Staging.anchor(s, [far]), Staging.zone_centre(zone)), "a roof outside the churchyard doesn't count")
	Data.use_island("hearthglow")

func test_places_are_given_facing_the_audience():
	var fr := Staging.frame({"audience": [0.0, -1.0]}, Vector2(10, 20))
	t.ok(_close(Staging.to_world(fr, [0.0, 2.0]), Vector2(10, 18)), "two metres towards the audience")
	t.ok(_close(Staging.to_world(fr, [1.0, 0.0]), Vector2(11, 20)) or _close(Staging.to_world(fr, [1.0, 0.0]), Vector2(9, 20)), "one to the side")
	t.ok(absf(Staging.to_world(fr, [1.0, 0.0]).distance_to(fr.origin) - 1.0) < 0.001, "sideways and forwards are square")
	var flat := Staging.frame({"audience": [0.0, 0.0]}, Vector2.ZERO)
	t.ok(_close(flat.fwd, Vector2(0, 1)), "no audience direction given: the default")

func test_a_place_in_a_wall_moves_to_the_nearest_free_spot():
	var wall := func(p: Vector2) -> bool: return p.x > 0.5
	var got := Staging.free_spot(Vector2(0.0, 0.0), func(p): return not wall.call(p))
	t.ok(_close(got, Vector2.ZERO), "a free place stays where it is")
	var moved := Staging.free_spot(Vector2(1.0, 0.0), func(p): return not wall.call(p))
	t.ok(moved.x <= 0.5 and moved.distance_to(Vector2(1.0, 0.0)) < 1.0, "one in the wall steps out of it, not far")
	var stuck := Staging.free_spot(Vector2(3.0, 0.0), func(p): return false)
	t.ok(_close(stuck, Vector2(3.0, 0.0)), "nowhere free: it keeps its place")

func test_the_crowd_fills_the_given_spots_first_then_rows():
	var fr := Staging.frame({"audience": [0.0, 1.0]}, Vector2.ZERO)
	var spec := {"crowd": {"spots": [[-2.0, 3.0], [2.0, 3.0]], "at": [0.0, 5.0], "gap": 1.0, "per_row": 3}}
	var sp := Staging.crowd_spots(fr, spec, 5)
	t.eq(sp.size(), 5, "one place each")
	t.ok(_close(sp[0], Staging.to_world(fr, [-2.0, 3.0])) and _close(sp[1], Staging.to_world(fr, [2.0, 3.0])), "the chosen spots first")
	for i in sp.size():
		for j in range(i + 1, sp.size()): t.ok(sp[i].distance_to(sp[j]) > 0.5, "nobody stands in anyone else")

func test_candles_light_one_after_another():
	var s := {"candles": {"from": [0.0, 0.0], "to": [7.0, 0.0], "count": 8, "every": 0.5}}
	var pts := Staging.candle_points(s)
	t.eq(pts.size(), 8, "eight candles")
	t.ok(_close(pts[0], Vector2(0, 0)) and _close(pts[7], Vector2(7, 0)) and _close(pts[3], Vector2(3, 0)), "evenly along the wall")
	t.eq(Staging.lit_count(s, -1.0), 0, "none before the lighting starts")
	t.eq(Staging.lit_count(s, 0.0), 1, "the first at once")
	t.eq(Staging.lit_count(s, 1.2), 3, "then one every half second")
	t.eq(Staging.lit_count(s, 60.0), 8, "and never more than there are")

func test_a_melody_is_notes_in_time_with_rests():
	var ev := Staging.melody({"kind": "flute", "step": 0.5, "vol": 0.3, "notes": [[60, 1], [0, 1], [62, 2], 64]})
	t.eq(ev.size(), 3, "a rest plays nothing")
	t.eq(ev[0], ["flute", 60, 0.3, 0.0], "the first note at once")
	t.ok(absf(float(ev[1][3]) - 1.0) < 0.001, "after a beat's note and a beat's rest")
	t.ok(absf(float(ev[2][3]) - 2.0) < 0.001, "a two-beat note holds before the next")

func test_actors_enter_on_their_line_from_the_side():
	var s := _scene()
	var first := Staging.entering(s, 0).map(func(a): return a.get("npc", a.get("node", "")))
	t.ok(first.has("rice_village_donkey") and first.has("rice_village_ox"), "the ox and the donkey come first")
	var holy := Staging.entering(s, 1).map(func(a): return a.get("npc", ""))
	t.ok(holy.has("rice_village_silvia") and holy.has("rice_village_battista") and holy.has("rice_village_matteo"), "the holy family and the shepherd on the second line")
	var e := Staging.entry_point({"enter": [-5.0, 1.0]}, {"at": [1.0, 2.0]})
	t.eq(e, [-4.0, 3.0], "without a start of its own an actor walks in from the scene's side")
	t.eq(Staging.entry_point({}, {"at": [0.0, 0.0], "from": [9.0, 9.0]}), [9.0, 9.0], "or from its own start")
	Data.use_island("hearthglow")

func test_walking_reaches_the_mark_without_overshooting():
	var p := Vector2.ZERO
	var steps := 0
	while p != Vector2(3, 4) and steps < 100:
		p = Staging.walk_step(p, Vector2(3, 4), 1.6, 0.1)
		steps += 1
	t.eq(p, Vector2(3, 4), "it arrives exactly")
	t.ok(steps >= 31 and steps <= 33, "five metres at 1.6 m/s takes about three seconds (%d steps)" % steps)
