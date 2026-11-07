extends RefCounted
var t
var statics: Array

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

func _ctx(list: Array, zone_id: String) -> Dictionary:
	return {"placements": list, "zones": [Data.zone(zone_id)], "statics": statics, "bodies": []}

func _random_site(rng: Rng, zone_id: String, ids: Array, tries: int) -> Array:
	var z: Dictionary = Data.zone(zone_id)
	var list: Array = []
	var uid := 1
	for n in tries:
		var id: String = ids[int(rng.next() * ids.size()) % ids.size()]
		var i := float(z.minI + int(rng.next() * (z.maxI - z.minI + 1)))
		var k := float(z.minK + int(rng.next() * (z.maxK - z.minK + 1)))
		var r := int(rng.next() * 4) % 4
		var y := BuildGrid.suggest_bottom(id, i, k, r, 10.0 if rng.next() < 0.7 else -1.0, list, z)
		var pl := {"uid": uid, "id": id, "i": i, "k": k, "r": r, "y": y}
		if BuildGrid.validate_placement(pl, _ctx(list, zone_id)).ok: list.append(pl); uid += 1
	return list

func _compare_support(zone_id: String, ids: Array, seed: int) -> Array:
	var rng := Rng.new(seed)
	var list := _random_site(rng, zone_id, ids, 160)
	var z: Dictionary = Data.zone(zone_id)
	var fast := _ctx(list, zone_id)
	fast["support_memo"] = {}
	var checked := 0
	var differ: Array = []
	for i in range(int(z.minI), int(z.maxI) + 1):
		for k in range(int(z.minK), int(z.maxK) + 1):
			for n in 3:
				var id: String = ids[int(rng.next() * ids.size()) % ids.size()]
				var r := int(rng.next() * 4) % 4
				var y := BuildGrid.suggest_bottom(id, i, k, r, 999.0, list, z)
				var pl := {"uid": -1, "id": id, "i": float(i), "k": float(k), "r": r, "y": y}
				var a := BuildGrid.validate_placement(pl, _ctx(list, zone_id))
				var b := BuildGrid.validate_placement(pl, fast)
				checked += 1
				if a.ok != b.ok or String(a.get("reason", "")) != String(b.get("reason", "")): differ.append("%s at %d,%d r%d" % [id, i, k, r])
	return [checked, differ, list.size()]

func test_fast_support_agrees_with_the_full_check():
	var spans := ["bridgeDeck", "bridgePost", "railing", "floor", "stoneBlock"]
	for seed in [3, 17, 2024]:
		var res := _compare_support("bridge", spans, seed)
		t.ok(res[1].is_empty(), "the washout, seed %d: %d checks over %d pieces, differing: %s" % [seed, res[0], res[2], str(res[1].slice(0, 5))])
	var house := ["floor", "stoneBlock", "platform", "woodWall", "roof", "pillar", "table"]
	for seed in [5, 99]:
		var res := _compare_support("plot", house, seed)
		t.ok(res[1].is_empty(), "the farmhouse plot, seed %d: %d checks over %d pieces, differing: %s" % [seed, res[0], res[2], str(res[1].slice(0, 5))])

func test_glowing_spots_are_exactly_where_pieces_fit():
	var rng := Rng.new(41)
	var list := _random_site(rng, "bridge", ["bridgeDeck", "bridgePost", "floor"], 80)
	var z: Dictionary = Data.zone("bridge")
	var ctx := _ctx(list, "bridge")
	ctx["support_memo"] = {}
	var wrong: Array = []
	var shown := 0
	for i in range(int(z.minI), int(z.maxI) + 1):
		for k in range(int(z.minK), int(z.maxK) + 1):
			var v := BuildGrid.spot("bridgeDeck", float(i), float(k), 0, ctx)
			var check := BuildGrid.validate_placement(v.pl, _ctx(list, "bridge"))
			if v.ok: shown += 1
			if v.ok != check.ok: wrong.append("%d,%d" % [i, k])
			if v.ok:
				var probe: Dictionary = v.pl.duplicate(); probe.uid = 999
				var after := list.duplicate(); after.append(probe)
				if not BuildGrid.compute_support(after, BuildGrid._env_for(z)).supported.has(999): wrong.append("%d,%d unsupported" % [i, k])
	t.ok(wrong.is_empty() and shown > 0, "%d spots glow for a plank, all of them places it fits (wrong: %s)" % [shown, str(wrong)])

func test_plank_reach_shows_in_the_spots():
	var z: Dictionary = Data.zone("bridge")
	var ctx := _ctx([], "bridge")
	ctx["support_memo"] = {}
	var dry := 0
	var wet := 0
	for i in range(int(z.minI), int(z.maxI) + 1):
		for k in range(int(z.minK), int(z.maxK) + 1):
			if not BuildGrid.spot("bridgeDeck", float(i), float(k), 0, ctx).ok: continue
			if BuildGrid.ground_at(i, k) >= Heightfield.WALKABLE_MIN: dry += 1
			else: wet += 1
	t.ok(dry > 0 and wet == 0, "with nothing built, planks can only start on the banks (%d dry spots, %d over water)" % [dry, wet])

func test_edge_pieces_turn_to_the_edge_you_point_at():
	var d := Data.piece("railing")
	t.eq(BuildGrid.edge_rotation(d, 0.0, -17.0, Vector3(0.5, 0.0, -16.95), 1), 0, "pointing at the north edge")
	t.eq(BuildGrid.edge_rotation(d, 0.0, -17.0, Vector3(0.95, 0.0, -16.5), 0), 1, "pointing at the east edge")
	t.eq(BuildGrid.edge_rotation(d, 0.0, -17.0, Vector3(0.5, 0.0, -16.05), 0), 2, "pointing at the south edge")
	t.eq(BuildGrid.edge_rotation(d, 0.0, -17.0, Vector3(0.05, 0.0, -16.5), 0), 3, "pointing at the west edge")
	t.eq(BuildGrid.edge_rotation(d, 0.0, -17.0, Vector3(0.52, 0.0, -16.48), 3), 3, "pointing at the middle keeps the way you turned it")
	for id in ["woodWall", "fence", "doorWall"]:
		var w := Data.piece(id)
		var r := BuildGrid.edge_rotation(w, 4.0, 2.0, Vector3(4.9, 0.0, 2.5), 0)
		var rc := BuildGrid.rect_of(w, {"i": 4.0, "k": 2.0, "r": r})
		t.ok(rc.minX > 4.6, "a %s pointed at its east edge stands on that edge" % id)

func _draft(uid: int, id: String, i: float, k: float, y: float = 0.0, r: int = 0) -> Dictionary:
	return {"uid": uid, "id": id, "i": i, "k": k, "r": r, "y": y}

func test_drafts_add_up_what_they_need():
	var drafts := [_draft(10, "bench", 3, 2), _draft(11, "bench", 5, 2), _draft(12, "lamp", 4, 3)]
	var cost := Drafts.cost(drafts)
	t.eq(cost.get("wood", 0), 2 * int(Data.piece("bench").cost.get("wood", 0)) + int(Data.piece("lamp").cost.get("wood", 0)), "the wood for two benches and a lamp")
	var short := Drafts.shortfall(drafts, {"wood": 1, "crystal": 1})
	t.ok(short.any(func(m): return m.id == "wood" and int(m.need) == int(cost.wood) - 1), "short of the wood you don't have")
	t.ok(not short.any(func(m): return m.id == "crystal"), "not short of the copper wire you have")
	t.eq(Drafts.items_text([{"id": "wood", "need": 4}, {"id": "coins", "need": 120}]), "4 wood, 120,000 lire", "the shopping list reads plainly")
	t.ok(Drafts.shortfall(drafts, {"wood": 99, "crystal": 9, "metal": 9}).is_empty(), "nothing short when you have it all")

func test_drafts_find_their_spot_and_build_bottom_up():
	var floor_d := _draft(20, "floor", 17, -35, 0.2)
	var bench_d := _draft(21, "bench", 17, -35, 0.35)
	var other := _draft(19, "floor", 18, -35, 0.2)
	var drafts := [bench_d, floor_d, other]
	t.eq(Drafts.find_same(drafts, {"id": "floor", "i": 17.0, "k": -35.0, "r": 4, "y": 0.21}).get("uid", -1), 20, "the same piece on the same spot is that draft")
	t.ok(Drafts.find_same(drafts, {"id": "bench", "i": 17.0, "k": -35.0, "r": 1, "y": 0.35}).is_empty(), "turned another way it isn't")
	var order: Array = Drafts.build_order(drafts).map(func(d): return int(d.uid))
	t.eq(order, [19, 20, 21], "floors before what stands on them")
	var design := Drafts.design([_draft(1, "stoneBlock", 0, 0)], drafts, 20)
	t.eq(design.map(func(d): return int(d.uid)), [1, 21, 19], "the design is what's built and what's drafted, leaving out the one being changed")
	t.eq(Drafts.find(drafts, 21).get("id", ""), "bench", "a draft found by its number")

func test_drafted_support_counts_for_the_design_only():
	var z: Dictionary = Data.zone("plot")
	var y0 := BuildGrid.suggest_bottom("platform", 17, -35, 0, 10.0, [], z)
	var platform := _draft(30, "platform", 17, -35, y0)
	var ok_floor := BuildGrid.validate_placement(platform, _ctx([], "plot"))
	t.ok(ok_floor.ok, "a platform fits on the plot: %s" % ok_floor.get("reason", ""))
	var top := y0 + float(Data.piece("platform").h)
	var chair := {"uid": -1, "id": "chair", "i": 17.0, "k": -35.0, "r": 0, "y": top}
	t.ok(BuildGrid.validate_placement(chair, _ctx([platform], "plot")).ok, "a chair can be drafted on a drafted platform")
	t.ok(not BuildGrid.validate_placement(chair, _ctx([], "plot")).ok, "but can't be built until the platform is")

func test_drafts_are_saved_and_stay_in_their_place():
	var s := GameState.new_game("Tester")
	t.eq(s.drafts, [], "a new game has an empty draft")
	s.placements = [_draft(3, "bridgeDeck", 0, -16)]
	s.drafts = [_draft(9, "bench", 4, 2)]
	var back := SaveSystem.deserialize(SaveSystem.serialize(s))
	t.ok(back.drafts.size() == 1 and back.drafts[0].id == "bench" and int(back.drafts[0].uid) == 9, "the draft comes back from a save")
	t.ok(int(back.next_uid) > 9, "new pieces never reuse a drafted piece's number (%d)" % int(back.next_uid))
	Travel.leave(back, "hearthglow", "river_town", {"x": 0.0, "z": 0.0})
	t.ok(back.drafts.is_empty() and back.away.hearthglow.drafts.size() == 1, "travelling, the draft stays behind with the place")
	t.ok(Travel.max_uid(back) >= 9, "and its numbers still count")
	var again := SaveSystem.deserialize(SaveSystem.serialize(back))
	t.eq(again.away.get("hearthglow", {}).get("drafts", []).size(), 1, "a save made away keeps it")
	Travel.leave(again, "river_town", "hearthglow", {"x": 0.0, "z": 0.0})
	t.ok(again.drafts.size() == 1 and again.drafts[0].id == "bench", "coming back, the draft is there again")

func test_monteforchetta_sites_are_open_from_the_start():
	for id in ["bridge", "workshop", "plaza", "dock"]:
		t.ok(not Data.zone(id).has("unlock"), "%s is open without waiting for its request" % Data.zone(id).name)
	t.eq(Data.zone("plot").get("unlock", {}), {"flag": "homePlot"}, "your own plot still needs its deed")

func test_draft_only_key_replaces_the_half_grid():
	t.ok(Controls.DEFAULTS.has("draft_only") and not Controls.DEFAULTS.has("half_grid"), "G is draft only now")
	t.ok(Controls.LABELS.has("draft_only"), "and it has a name in the key settings")
