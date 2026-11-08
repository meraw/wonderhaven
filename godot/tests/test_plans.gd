extends RefCounted
## Ghost plans (Plans): every building step of Monteforchetta's and Boccapioppo's requests has one, building it,
## piece by piece in the order given, is allowed at every step and finishes the step, and what the request has you
## gather pays for it.
var t
var statics: Array

## The places whose every building step has a plan (the others' are their owners' to add).
const PLACES := ["hearthglow", "river_town"]

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

const BUILD_KINDS := ["build", "pieces", "room", "commission"]

func test_every_building_step_has_a_plan():
	for q in Data.quests:
		if not PLACES.has(Data.quest_island(q.id)): continue
		for o in q.objectives:
			if o.kind in BUILD_KINDS: t.ok(o.has("plan") and not o.plan.is_empty(), "%s: \"%s\" has a plan" % [q.title, o.text])

## Builds a quest's plans, step by step, onto `placements`; returns false (with a failure noted) if a piece can't go
## where its plan says. `flags_for` gives the story flags a step's place is laid out for (Boccapioppo's houseboat has
## been launched by the time you furnish her cabin).
func _build(q: Dictionary, placements: Array, flags_for: Callable = func(_o): return {}) -> bool:
	var steps: Array = q.objectives.filter(func(o): return o.has("plan"))
	steps.sort_custom(func(a, b): return QuestEngine.stage_of(a) < QuestEngine.stage_of(b))
	for o in steps:
		Data.apply_world_flags(flags_for.call(o))
		var here := WorldStatics.build_statics(WorldStatics.generate_decor()) if Data.island != "hearthglow" else statics
		var zone := Data.zone(String(o.get("zone", "")))
		for pl in Plans.lay_out(o.plan, zone, placements):
			var y := BuildGrid.suggest_bottom(pl.id, pl.i, pl.k, int(pl.r), 10.0, placements, zone)
			if absf(y - float(pl.y)) > 0.01:
				t.ok(false, "%s: the ghost %s at (%d, %d) sits at %.2f, but builds at %.2f" % [q.id, pl.id, pl.i, pl.k, pl.y, y]); return false
			pl.uid = placements.size() + 1
			var v := BuildGrid.validate_placement(pl, {"placements": placements, "zones": Data.layout.zones, "statics": here, "bodies": [], "flags": {}})
			if not v.ok:
				t.ok(false, "%s: %s at (%d, %d) turned %d can't be built: %s" % [q.id, pl.id, pl.i, pl.k, pl.r, v.reason]); return false
			placements.append(pl)
		t.ok(_done(o, placements, here), "%s: building its plan finishes \"%s\"" % [q.title, o.text])
	return true

func _done(o: Dictionary, placements: Array, here: Array) -> bool:
	if o.kind == "commission":
		var F2: Dictionary = Data.layout.get("fountain", {})
		var targets: Array = [{"id": "fountain", "cell": F2.inlet.cell, "side": F2.inlet.side, "type": "water"}] if F2.has("inlet") else []
		targets.append_array(Data.layout.get("machines", []))
		var m := Mechanics.solve(placements, targets)
		var path := func(zone_id: String) -> Dictionary:
			var w := WalkWorld.new(here, func(_f): return false)
			w.floors = WorldStatics.floors()
			w.surfaces = BuildGrid.surfaces_for(placements)
			return Validate.path_across(Data.zone(zone_id), w)
		return Commission.evaluate(o, {"placements": placements, "lamps": m.lamps, "fed": m.fed, "mech": m, "path": path}).done
	match o.kind:
		"room": return Validate.room_checklist(Data.zone(o.zone), placements, o.needs).all(func(r): return r.ok)
		"pieces":
			var n := Validate.pieces_in_zone(Data.zone(o.zone), placements).filter(func(p): return o.any.has(p.id)).size()
			return n >= int(o.count)
		"build":
			var F: Dictionary = Data.layout.get("fountain", {})
			var inlets: Array = [{"id": "fountain", "cell": F.inlet.cell, "side": F.inlet.side, "type": "water"}] if F.has("inlet") else []
			inlets.append_array(Data.layout.get("machines", []))
			var mech := Mechanics.solve(placements, inlets)
			var check := String(o.check)
			var walked := func(zone_id: String) -> bool:
				var w := WalkWorld.new(here, func(_f): return false)
				w.floors = WorldStatics.floors()
				w.surfaces = BuildGrid.surfaces_for(placements)
				return Validate.path_across(Data.zone(zone_id), w).ok
			if check == "fountain": return mech.fed.get("fountain", false)
			if check == "lamp": return not mech.lamps.is_empty()
			if check in ["bridge", "dock"]: return walked.call(String(o.zone))
			if check.begins_with("path:"): return walked.call(check.substr(5))
			if check.begins_with("sealed:"): return Validate.sealed(Data.zone(check.substr(7)), placements).sealed
			if check.begins_with("fed:"): return mech.fed.get(check.substr(4), false)
	return false

func test_the_plans_work():
	for id in ["bridge", "workshop", "fountain", "home", "dock", "lamp"]:
		_build(Data.quest(id), [])
	# the lamp's plan works beside a fountain built to its plan, and the farmhouse's bed fits the house
	var piazza: Array = []
	_build(Data.quest("fountain"), piazza)
	_build(Data.quest("lamp"), piazza)

## Boccapioppo: the pontoon bridge and its railings, the waterwheel for the pumping house, the dance hall, the wall
## across the breach, and the houseboat's slipway and (once she's afloat) her cabin.
func test_boccapioppos_plans_work():
	Data.use_island("river_town")
	var launched := func(o): return {"river_town_launched": true} if o.id == "cosy" else {}
	for q in Data.quests.filter(func(x): return Data.quest_island(x.id) == "river_town"):
		if q.objectives.any(func(o): return o.has("plan")): _build(q, [], launched)
	Data.use_island("hearthglow")

## What a request has you gather pays for following its plans (gifts on accepting are in your bag, so they count
## towards it): you never tick off the materials and then come up short on the last plank.
func test_gathering_pays_for_the_plan():
	for q in Data.quests:
		var gather := {}
		for o in q.objectives:
			if o.kind == "gather": gather[o.item] = int(o.count)
		var cost := {}
		for o in q.objectives:
			for e in o.get("plan", []):
				var c: Dictionary = Data.piece(String(e[2])).get("cost", {})
				for k in c: cost[k] = int(cost.get(k, 0)) + int(c[k])
		for k in gather:
			t.ok(int(gather[k]) >= int(cost.get(k, 0)), "%s: gathering %d %s pays for the %d its plan takes" % [q.id, gather[k], k, cost.get(k, 0)])

func test_plan_ghosts_and_what_is_built():
	var pls := Plans.lay_out([[0, -18, "bridgePost"], [0, -18, "bridgeDeck"]], Data.zone("bridge"))
	t.ok(float(pls[1].y) > float(pls[0].y) + 0.1, "the deck's ghost rests on its post's")
	var rail := {"id": "railing", "i": 0.0, "k": -17.0, "r": 3, "y": 0.0}
	t.ok(Plans.built(rail, [{"id": "railing", "i": 0.0, "k": -17.0, "r": 3}]), "a railing on that edge is the one in the plan")
	t.ok(not Plans.built(rail, [{"id": "railing", "i": 0.0, "k": -17.0, "r": 1}]), "one on the other edge isn't")
	var s := GameState.new_game()
	var e := QuestEngine.new(s)
	s.quests["bridge"] = {"status": "active", "progress": {"wood": 14}}
	e.invalidate()
	var now := Plans.current(e)
	t.ok(now.size() == 1 and now[0].objective == "build", "with the wood gathered, the crossing's plan shows")
	# the next piece to build: the first of the plan not built yet (BuildMode follows it)
	var nx := Plans.next_piece(now[0].pieces, [])
	t.ok(not nx.is_empty() and nx.id == String(Data.quest("bridge").objectives[1].plan[0][2]), "the next piece is the plan's first")
	var first: Dictionary = now[0].pieces[0]
	t.ok(Plans.next_piece(now[0].pieces, [first]) != first, "...and once it's built, the one after")
