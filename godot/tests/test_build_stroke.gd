extends RefCounted
var t
var statics: Array
var uid := 1

func _init() -> void:
	Data.use_island("hearthglow")
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

func _ctx(list: Array) -> Dictionary:
	return {"placements": list, "zones": Data.layout.zones, "statics": statics, "bodies": []}

func _fits(list: Array, pl: Dictionary) -> bool:
	return BuildGrid.validate_placement(pl, _ctx(list)).ok

func _put(list: Array, id: String, i: float, k: float, r: int = 0, hit_y: float = 10.0) -> Dictionary:
	var zone := BuildGrid.zone_at(Data.layout.zones, i, k)
	var pl := {"uid": uid, "id": id, "i": i, "k": k, "r": r, "y": BuildGrid.suggest_bottom(id, i, k, r, hit_y, list, zone)}
	uid += 1
	if not _fits(list, pl): return {}
	list.append(pl)
	return pl

func _anchor(list: Array, pl: Dictionary) -> Dictionary:
	var below: Array = list.filter(func(q): return int(q.uid) != int(pl.uid))
	return BuildStroke.anchor(pl, below, BuildGrid.zone_at(Data.layout.zones, float(pl.i), float(pl.k)))

func _drag(list: Array, a: Dictionary, cells: Array) -> Array:
	var added: Array = []
	var done := {Vector2i.ZERO: true}
	for cell in cells:
		if done.has(cell): continue
		var c := BuildStroke.candidate(a, cell, list, Data.layout.zones)
		if c.is_empty(): continue
		c["uid"] = uid
		uid += 1
		if not _fits(list, c): continue
		list.append(c)
		added.append(c)
		done[cell] = true
	return added

func _free_row(id: String, zone_id: String, n: int) -> Vector2:
	var z: Dictionary = Data.zone(zone_id)
	for k in range(int(z.minK), int(z.maxK) + 1):
		for i in range(int(z.minI), int(z.maxI) - n + 2):
			var free := true
			for step in n:
				var pl := {"uid": -1, "id": id, "i": float(i + step), "k": float(k), "r": 0, "y": BuildGrid.suggest_bottom(id, float(i + step), float(k), 0, 10.0, [], z)}
				if not _fits([], pl): free = false; break
			if free: return Vector2(i, k)
	return Vector2.INF

func _bridge(list: Array) -> void:
	for k in [-15, -16, -17]: _put(list, "bridgeDeck", 1, k)
	_put(list, "bridgePost", 1, -18, 0, -1.4)
	for k in [-18, -19, -20, -22, -21]: _put(list, "bridgeDeck", 1, k, 0, 0.1)

func test_a_click_with_a_shaky_hand_is_not_a_drag():
	t.ok(not BuildStroke.started(Vector2(400, 300), Vector2(404, 303)), "a few pixels of wobble is still a click")
	t.ok(not BuildStroke.started(Vector2(400, 300), Vector2(400, 300)), "no movement is a click")
	t.ok(BuildStroke.started(Vector2(400, 300), Vector2(400 + BuildStroke.START_PX, 300)), "a real move starts the drag")

func test_a_fast_drag_misses_no_cell_on_the_way():
	var straight := BuildStroke.line(Vector2i(0, 0), Vector2i(5, 0))
	t.eq(straight, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)], "a straight sweep")
	t.eq(BuildStroke.line(Vector2i(2, 3), Vector2i(2, 3)), [], "staying put adds nothing")
	for to in [Vector2i(4, -3), Vector2i(-6, 2), Vector2i(-1, -7), Vector2i(3, 3)]:
		var path := BuildStroke.line(Vector2i(0, 0), to)
		var prev := Vector2i(0, 0)
		var joined := true
		for c in path:
			if absi(c.x - prev.x) > 1 or absi(c.y - prev.y) > 1 or c == prev: joined = false
			prev = c
		t.ok(joined and not path.is_empty() and path.back() == to and not path.has(Vector2i(0, 0)), "a sweep to %s is unbroken and ends there: %s" % [to, path])
	t.eq(BuildStroke.line(Vector2i(0, 0), Vector2i(200, 4)), [Vector2i(200, 4)], "a jump across the map is one step, not a wall")

func test_paving_dragged_over_the_ground_stays_on_the_ground():
	var at := _free_row("gardenPath", "plaza", 6)
	t.ok(at != Vector2.INF, "the piazza has six free tiles in a row")
	if at == Vector2.INF: return
	var list: Array = []
	var already := _put(list, "gardenPath", at.x + 3, at.y)
	var first := _put(list, "gardenPath", at.x, at.y)
	var a := _anchor(list, first)
	t.ok(a.ground and not a.edge, "the first stone lies on the ground")
	var sweep: Array = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
	var added := _drag(list, a, sweep)
	t.eq(added.size(), 4, "four more stones: the tile that already had one is passed over")
	var flat := true
	for pl in added:
		var zone := BuildGrid.zone_at(Data.layout.zones, float(pl.i), float(pl.k))
		if absf(float(pl.y) - BuildGrid.suggest_bottom("gardenPath", float(pl.i), float(pl.k), 0, BuildStroke.NO_STACK, [], zone)) > 0.001: flat = false
		if int(pl.k) != int(at.y): flat = false
	t.ok(flat, "each one lies on the ground of its own tile, none on another stone")
	t.ok(not added.any(func(pl): return is_equal_approx(float(pl.i), float(already.i))), "nothing was stacked on the stone that was there")
	t.eq(_drag(list, a, sweep).size(), 0, "sweeping back over them adds nothing")

func test_big_pieces_tile_edge_to_edge():
	var list: Array = []
	var first := _put(list, "platform", 14, -36)
	t.ok(not first.is_empty(), "a raised platform on the farmhouse plot")
	if first.is_empty(): return
	var a := _anchor(list, first)
	t.eq(Vector2i(int(a.fx), int(a.fz)), Vector2i(2, 2), "it covers two tiles each way")
	t.eq(BuildStroke.cell_at(a, 15.9, -34.1), Vector2i(0, 0), "anywhere over the first platform is still the first")
	t.eq(BuildStroke.cell_at(a, 16.1, -35.5), Vector2i(1, 0), "past its edge is the next one")
	t.eq(BuildStroke.cell_at(a, 13.9, -36.5), Vector2i(-1, -1), "and the other way")
	t.eq(BuildStroke.origin(a, Vector2i(1, 0)), Vector2(16, -36), "the next one starts where the first ends")
	var added := _drag(list, a, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)])
	t.eq(added.size(), 3, "three more platforms, none bumping into another")
	var bench := {"uid": 900, "id": "bench", "i": 3.0, "k": 2.0, "r": 1, "y": 0.0}
	var b := BuildStroke.anchor(bench, [], Data.zone("plaza"))
	t.eq(Vector2i(int(b.fx), int(b.fz)), Vector2i(1, 2), "a bench turned a quarter is one tile wide and two long")
	t.eq(BuildStroke.origin(b, Vector2i(0, 2)), Vector2(3, 6), "so benches in a row step two tiles")

func test_a_fence_dragged_runs_straight_along_its_edge():
	var at := _free_row("fence", "plaza", 6)
	t.ok(at != Vector2.INF, "the piazza has six free tiles in a row")
	if at == Vector2.INF: return
	for r in 4:
		var pl := {"uid": 700 + r, "id": "fence", "i": at.x + 2, "k": at.y, "r": r, "y": BuildGrid.suggest_bottom("fence", at.x + 2, at.y, r, 10.0, [], Data.zone("plaza"))}
		var a := BuildStroke.anchor(pl, [], Data.zone("plaza"))
		var rect := BuildGrid.rect_of(Data.piece("fence"), pl)
		var runs_x: bool = rect.maxX - rect.minX > rect.maxZ - rect.minZ
		t.ok(a.edge and bool(a.along_x) == runs_x, "turned %d, the fence runs %s" % [r, "east-west" if runs_x else "north-south"])
		var wobbly := BuildStroke.cell_at(a, at.x + 5.4, at.y + 2.7)
		t.eq(wobbly, Vector2i(3, 0) if runs_x else Vector2i(0, 2), "a wobbly hand stays on the fence's own line (turned %d)" % r)
		var c := BuildStroke.candidate(a, wobbly, [], Data.layout.zones)
		t.ok(int(c.r) == r and (int(c.k) == int(at.y) if runs_x else int(c.i) == int(at.x) + 2), "and the next piece keeps its edge and its row")
	var list: Array = []
	var first := _put(list, "fence", at.x, at.y, 0)
	var a0 := _anchor(list, first)
	var along: Array = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] if a0.along_x else [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
	var added := _drag(list, a0, along)
	t.ok(added.size() >= 1 and added.all(func(pl): return int(pl.r) == 0), "the fence grows along its line, every piece on the same edge (%d added)" % added.size())

func test_railings_dragged_along_a_bridge_stay_on_its_deck():
	var list: Array = []
	_bridge(list)
	var first := _put(list, "railing", 1, -16, 1, 0.3)
	t.ok(not first.is_empty(), "a railing on the bridge")
	if first.is_empty(): return
	var a := _anchor(list, first)
	t.ok(not a.ground and a.edge and not a.along_x, "it stands on the deck and runs along the bridge")
	var added := _drag(list, a, [Vector2i(0, -1), Vector2i(0, -2), Vector2i(0, -3), Vector2i(0, -4), Vector2i(0, -5), Vector2i(0, -6)])
	t.eq(added.size(), 6, "one railing for each plank on the way across")
	var on_deck := true
	for pl in added:
		var deck: Array = list.filter(func(q): return q.id == "bridgeDeck" and int(q.k) == int(pl.k))
		if deck.is_empty() or absf(float(pl.y) - (float(deck[0].y) + float(Data.piece("bridgeDeck").h))) > 0.02 or int(pl.r) != 1 or int(pl.i) != 1: on_deck = false
	t.ok(on_deck, "each on top of its plank, on the same side")
	var chair := _put(list, "chair", 1, -19, 0, 0.3)
	var ca := _anchor(list, chair)
	t.ok(not ca.ground, "a chair on the deck")
	t.eq(BuildStroke.candidate(ca, Vector2i(1, 0), list, Data.layout.zones), {}, "dragged off the side of the bridge it is not dropped in the stream")
	t.ok(not BuildStroke.candidate(ca, Vector2i(0, -1), list, Data.layout.zones).is_empty(), "dragged along the deck it goes on the next plank")

func test_a_drag_does_not_pile_a_piece_on_its_own_kind_unless_it_began_that_way():
	var list: Array = []
	_put(list, "platform", 14, -36)
	_put(list, "platform", 16, -36)
	var first := _put(list, "floor", 14, -36)
	var other := _put(list, "floor", 15, -36)
	t.ok(not first.is_empty() and not other.is_empty() and float(first.y) > 0.9, "two floor tiles on a raised platform")
	if first.is_empty() or other.is_empty(): return
	var a := _anchor(list, first)
	t.ok(not a.ground and not a.self, "the first tile lies on the platform")
	var added := _drag(list, a, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])
	t.eq(added.size(), 2, "it fills the platform's free tiles and stops at its end")
	t.ok(added.all(func(pl): return absf(float(pl.y) - float(first.y)) < 0.02), "all on the platform's top, none on the tile that was there")
	var blocks: Array = []
	for i in [14, 15, 16]: _put(blocks, "stoneBlock", i, -33)
	var top := _put(blocks, "stoneBlock", 14, -33, 0, 1.0)
	var b := _anchor(blocks, top)
	t.ok(not b.ground and b.self, "a second course of stone begins on a block")
	var course := _drag(blocks, b, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	t.eq(course.size(), 2, "it is laid along the blocks below, and not past them down on the ground")
	t.ok(course.all(func(pl): return absf(float(pl.y) - float(top.y)) < 0.02), "at the second course's height")

func test_walls_meet_at_the_corner_of_a_tile():
	var list: Array = []
	for i in [15, 16, 17]:
		for k in [-35, -34]: _put(list, "floor", i, k)
	t.eq(list.size(), 6, "a floor of six tiles on the farmhouse plot")
	var north := _put(list, "woodWall", 15, -35, 0, 0.2)
	var west := _put(list, "woodWall", 15, -35, 3, 0.2)
	t.ok(not north.is_empty() and not west.is_empty(), "the north wall and the west wall share the corner tile")
	if north.is_empty() or west.is_empty(): return
	t.ok(_put(list, "woodWall", 15, -35, 0, 0.2).is_empty(), "a second wall on the same edge still bumps into the first")
	t.ok(_put(list, "fence", 15, -35, 3, 0.2).is_empty(), "and so does a fence on an edge that has a wall")
	t.ok(_put(list, "table", 15, -35, 0, 0.2).is_empty(), "furniture still needs a tile clear of walls")
	var a := _anchor(list, west)
	t.ok(not a.along_x and not a.ground, "the west wall runs north-south, on the floor")
	t.eq(_drag(list, a, [Vector2i(0, 1)]).size(), 1, "dragged on, the west side is walled to the end of the floor")
	var along := _anchor(list, north)
	t.eq(_drag(list, along, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]).size(), 2, "and the north side to its end, not past it onto the grass")
	var east := _put(list, "woodWall", 17, -35, 1, 0.2)
	t.ok(not east.is_empty(), "the far corner closes the same way")
	var walls: Array = list.filter(func(q): return q.id == "woodWall")
	t.ok(walls.all(func(q): return absf(float(q.y) - float(north.y)) < 0.05), "every wall stands on the floor")

func test_one_drag_is_one_undo():
	var h := History.new()
	var seen: Array = []
	var apply := func(cmd: Dictionary, dir: String) -> Dictionary:
		seen.append("%s %d" % [dir, int(cmd.n)])
		return {"ok": true}
	h.push({"n": 0})
	h.begin_group()
	for n in [1, 2, 3]: h.push({"n": n})
	t.eq(h.done.size(), 1, "pieces put down during a drag wait for the drag to end")
	h.end_group()
	t.eq(h.done.size(), 2, "the whole drag is one step")
	t.ok(h.undo(apply).ok, "undo")
	t.eq(seen, ["undo 3", "undo 2", "undo 1"], "undo takes the drag back, last piece first")
	seen.clear()
	t.ok(h.redo(apply).ok, "redo")
	t.eq(seen, ["redo 1", "redo 2", "redo 3"], "redo puts it back in the order it was built")
	h.begin_group()
	h.push({"n": 9})
	h.end_group()
	t.eq(h.done.back(), {"n": 9}, "a click that built one piece is a plain step")
	var steps := h.done.size()
	h.begin_group()
	h.end_group()
	t.eq(h.done.size(), steps, "a press that built nothing leaves no step")
	h.begin_group()
	h.push({"n": 5})
	h.clear()
	h.push({"n": 6})
	t.eq(h.done, [{"n": 6}], "clearing the history forgets a drag in progress")

func test_a_drag_that_cannot_be_undone_whole_is_left_whole():
	var h := History.new()
	var seen: Array = []
	var stuck := func(cmd: Dictionary, dir: String) -> Dictionary:
		seen.append("%s %d" % [dir, int(cmd.n)])
		if dir == "undo" and int(cmd.n) == 1: return {"ok": false, "reason": "The roof rests on it"}
		return {"ok": true}
	h.begin_group()
	for n in [1, 2, 3]: h.push({"n": n})
	h.end_group()
	var r := h.undo(stuck)
	t.ok(not r.ok and String(r.reason) == "The roof rests on it", "undo says why it stopped")
	t.eq(seen, ["undo 3", "undo 2", "undo 1", "redo 2", "redo 3"], "the pieces it had taken away are put back")
	t.ok(h.can_undo() and not h.can_redo(), "and the drag is still there to undo later")
