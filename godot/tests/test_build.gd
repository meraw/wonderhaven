extends RefCounted
var t
var uid := 1
var statics: Array

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

func place(list: Array, id: String, i: float, k: float, r: int = 0, zone_id: String = "plot", hit_y: float = 10.0) -> Dictionary:
	var z: Dictionary = Data.zone(zone_id)
	var y := BuildGrid.suggest_bottom(id, i, k, r, hit_y, list, z)
	var pl := {"uid": uid, "id": id, "i": i, "k": k, "r": r, "y": y}
	uid += 1
	var v := BuildGrid.validate_placement(pl, {"placements": list, "zones": [z], "statics": statics, "bodies": []})
	if v.ok: list.append(pl)
	v["pl"] = pl
	return v

func test_catalog():
	t.ok(Data.pieces.size() >= 25, "%d pieces" % Data.pieces.size())
	for c in Data.categories:
		t.ok(Data.pieces.any(func(p): return p.cat == c.id), c.id)

func test_rotation_round_trip():
	var d := Data.piece("sofa")
	t.eq(BuildGrid.footprint(d, 1), Vector2(1, 2), "rotated footprint")
	for r in 4:
		var pl := {"id": "sofa", "i": 3.0, "k": 4.0, "r": r, "y": 0.0}
		var w := BuildGrid.local_to_world(d, pl, 0.3, 0.7)
		var l := BuildGrid.world_to_local(d, pl, w.x, w.y)
		t.ok(absf(l.x - 0.3) < 1e-6 and absf(l.y - 0.7) < 1e-6, "r=%d" % r)

func test_stacking_and_overlap():
	var list: Array = []
	t.ok(place(list, "stoneBlock", 17, -35).ok)
	var second := place(list, "stoneBlock", 17, -35, 0, "plot", 1.0)
	t.ok(second.ok, second.get("reason", ""))
	t.ok(absf(second.pl.y - (list[0].y + 1.0)) < 1e-6, "stacked")
	var clash := {"uid": 999, "id": "table", "i": 17.0, "k": -35.0, "r": 0, "y": list[0].y}
	var v := BuildGrid.validate_placement(clash, {"placements": list, "zones": [Data.zone("plot")], "statics": statics})
	t.ok(not v.ok and "Bumps into" in v.reason, v.get("reason", ""))

func test_zone_warnings():
	var pl := {"uid": 5000, "id": "floor", "i": -30.0, "k": 30.0, "r": 0, "y": 0.0}
	var v := BuildGrid.validate_placement(pl, {"placements": [], "zones": [Data.zone("plot")], "statics": statics})
	t.ok(not v.ok and "Outside" in v.reason)
	pl.i = 0.0; pl.k = -16.0
	v = BuildGrid.validate_placement(pl, {"placements": [], "zones": [Data.zone("plot")], "locked_zones": Data.layout.zones, "statics": statics})
	t.ok("The washout" in v.reason, v.reason)

func test_span_rule_and_removal():
	var list: Array = []
	for k in [-15, -16, -17]: t.ok(place(list, "bridgeDeck", 0, k, 0, "bridge").ok, "deck %d" % k)
	var far := place(list, "bridgeDeck", 0, -18, 0, "bridge")
	t.ok(not far.ok and "bridge post" in far.reason)
	var post := place(list, "bridgePost", 0, -18, 0, "bridge", -1.4)
	t.ok(post.ok, post.get("reason", ""))
	t.ok(absf(post.pl.y + 1.4) < 0.01, "post on the river bed")
	for k in [-18, -19, -20, -22, -21]:
		var r := place(list, "bridgeDeck", 0, k, 0, "bridge", 0.1)
		t.ok(r.ok, "deck %d: %s" % [k, r.get("reason", "")])
	t.ok(not BuildGrid.validate_removal(post.pl.uid, {"placements": list, "zones": [Data.zone("bridge")]}).ok, "post holds planks")

func test_bridge_is_walkable():
	var list: Array = []
	var walk := WalkWorld.new(statics)
	t.ok(not Validate.path_across(Data.zone("bridge"), walk).ok, "no path before")
	for k in [-15, -16, -17]: place(list, "bridgeDeck", 1, k, 0, "bridge")
	place(list, "bridgePost", 1, -18, 0, "bridge", -1.4)
	for k in [-18, -19, -20, -22, -21]: place(list, "bridgeDeck", 1, k, 0, "bridge", 0.1)
	walk.surfaces = BuildGrid.surfaces_for(list)
	t.ok(Validate.path_across(Data.zone("bridge"), walk).ok, "path found")
	var p := Vector3(1.5, 0, -13.5)
	for n in 120: p = walk.step_move(p, 0, -0.1).pos
	t.ok(p.z < -22.5, "walked across (z=%.2f)" % p.z)
	# railings along both sides (the bridge request's last step) keep the bridge walkable and count in its zone
	var rails: Array = list.duplicate()
	for k in [-16, -17, -18, -19]:
		var v := place(rails, "railing", 1, k, 1 if k % 2 == 0 else 3, "bridge", 0.3)
		t.ok(v.ok, "a railing fits along the bridge at k=%d (%s)" % [k, v.get("reason", "")])
	walk.surfaces = BuildGrid.surfaces_for(rails)
	t.ok(Validate.path_across(Data.zone("bridge"), walk).ok, "railings along the sides don't block the way")
	t.eq(Validate.pieces_in_zone(Data.zone("bridge"), rails).filter(func(p): return p.id == "railing").size(), 4, "all four count as on the bridge")
	# ...and with railings on both sides of the same tiles, a walker still fits between them
	for k in [-16, -17, -18, -19]:
		var v := place(rails, "railing", 1, k, 3 if k % 2 == 0 else 1, "bridge", 0.3)
		t.ok(v.ok, "a railing fits on the other side at k=%d (%s)" % [k, v.get("reason", "")])
	walk.surfaces = BuildGrid.surfaces_for(rails)
	var q := Vector3(1.44, 0, -13.5)   # a little off the middle, as real steering is
	for n in 140: q = walk.step_move(q, 0, -0.1).pos
	t.ok(q.z < -22.5, "walked between railings on both sides, a little off-centre (z=%.2f)" % q.z)
	list.append({"uid": 777, "id": "railing", "i": 1.0, "k": -19.0, "r": 0, "y": 0.15})
	walk.surfaces = BuildGrid.surfaces_for(list)
	t.ok(not Validate.path_across(Data.zone("bridge"), walk).ok, "railing blocks")

func test_door_and_stairs():
	var door := {"uid": 1, "id": "doorWall", "i": 20.0, "k": 10.0, "r": 0, "y": 0.0, "state": {"open": false}}
	var walk := WalkWorld.new([])
	walk.surfaces = BuildGrid.surfaces_for([door])
	var p := Vector3(20.5, 0, 11)
	for n in 20: p = walk.step_move(p, 0, -0.1).pos
	t.ok(p.z > 10.1, "closed door blocks")
	door.state.open = true
	walk.surfaces = BuildGrid.surfaces_for([door])
	for n in 20: p = walk.step_move(p, 0, -0.1).pos
	t.ok(p.z < 9.9, "open door lets you through")
	var list: Array = []
	t.ok(place(list, "platform", 17, -36).ok)
	t.ok(place(list, "stairs", 17, -34).ok)
	walk.surfaces = BuildGrid.surfaces_for(list)
	p = Vector3(17.5, walk.surface_at(17.5, -32.4).y, -32.4)
	var y0 := p.y
	for n in 40: p = walk.step_move(p, 0, -0.08).pos
	t.ok(p.y > y0 + 0.9, "climbed (y=%.2f)" % p.y)

func test_fountain_mechanism():
	var inlets := [{"id": "fountain", "cell": Data.layout.fountain.inlet.cell, "side": Data.layout.fountain.inlet.side}]
	var bp: Array = []
	var n := 100
	for e in Data.zone("plaza").blueprint:
		bp.append({"uid": n, "id": e[2], "i": float(e[0]), "k": float(e[1]), "r": int(e[3]) if e.size() > 3 else 0, "y": -0.35 if e[2] == "waterwheel" else 0.0}); n += 1
	t.ok(Mechanics.solve(bp, inlets).fed.fountain, "blueprint feeds the fountain")
	t.ok(not Mechanics.solve(bp.filter(func(p): return not (p.id == "pipe" and p.i == 5)), inlets).fed.fountain, "gap stops water")
	var no_gear := Mechanics.solve(bp.filter(func(p): return p.id != "gear"), inlets)
	t.ok(no_gear.pumps.is_empty() and not no_gear.fed.fountain, "no power, no water")

func test_windmill_lamp_lever():
	var list := [{"uid": 1, "id": "windmill", "i": 20.0, "k": 10.0, "r": 0, "y": 0.0}, {"uid": 2, "id": "lever", "i": 20.0, "k": 11.0, "r": 0, "y": 0.0, "state": {"on": true}}, {"uid": 3, "id": "poweredLamp", "i": 20.0, "k": 12.0, "r": 0, "y": 0.0}]
	t.ok(Mechanics.solve(list).lamps.has(3), "lamp lit")
	list[1].state.on = false
	t.ok(not Mechanics.solve(list).lamps.has(3), "lever off")

func test_room_checklist():
	var list := [{"uid": 1, "id": "chair", "i": -15.0, "k": 8.0, "r": 0, "y": 0.0, "color": "#7bd389"}, {"uid": 2, "id": "lamp", "i": -14.0, "k": 8.0, "r": 0, "y": 0.0}]
	var res := Validate.room_checklist(Data.zone("workshop"), list, [{"any": ["chair"], "label": "a"}, {"any": ["workbench"], "label": "b"}, {"recolored": true, "label": "c"}])
	t.eq(res.map(func(r): return r.ok), [true, false, true], "checklist")

func test_history():
	var h := History.new()
	var log: Array = []
	var apply := func(c, dir): log.append("%s:%d" % [dir, c.n]); return {"ok": true}
	h.push({"n": 1}); h.push({"n": 2})
	h.undo(apply); h.undo(apply)
	t.ok(not h.undo(apply).ok)
	h.redo(apply)
	t.eq(log, ["undo:2", "undo:1", "redo:1"], "order")

func test_bus_turnaround():
	# the finale: pave the turning circle on the belvedere, then a bench and a sign for the stop
	var list: Array = []
	var z: Dictionary = Data.zone("dock")
	var paving := 0
	for i in range(int(z.minI) + 1, int(z.maxI)):
		for k in [int(z.minK) + 1, int(z.minK) + 2]:
			var r := place(list, "gardenPath", i, k, 0, "dock", 0.3)
			t.ok(r.ok, "paving at %d,%d: %s" % [i, k, r.get("reason", "")])
			if r.ok: paving += 1
	var bench := place(list, "bench", int(z.minI) + 2, int(z.maxK) - 1, 0, "dock", 0.3)
	t.ok(bench.ok, bench.get("reason", ""))
	var sign := place(list, "signpost", int(z.maxI) - 1, int(z.maxK) - 1, 0, "dock", 0.3)
	t.ok(sign.ok, sign.get("reason", ""))
	var q := Data.quest("dock")
	for o in q.objectives:
		if o.kind != "pieces": continue
		var n := Validate.pieces_in_zone(z, list).filter(func(pl): return o.any.has(pl.id)).size()
		t.ok(n >= int(o.get("count", 1)), "%s (%d placed)" % [o.text, n])
	var walk := WalkWorld.new(statics)
	walk.surfaces = BuildGrid.surfaces_for(list)
	t.ok(walk.surface_at(float(z.minI) + 2.5, float(z.minK) + 1.5).walkable, "you can walk on the paving")
