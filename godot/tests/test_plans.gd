extends RefCounted
## Ghost plans (Plans): every building step of Monteforchetta's requests has one, and building it, piece by piece in
## the order given, is allowed at every step and finishes the step.
var t
var statics: Array

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

const BUILD_KINDS := ["build", "pieces", "room"]

func test_every_building_step_has_a_plan():
	for q in Data.quests:
		if Data.quest_island(q.id) != "hearthglow": continue
		for o in q.objectives:
			if o.kind in BUILD_KINDS: t.ok(o.has("plan") and not o.plan.is_empty(), "%s: \"%s\" has a plan" % [q.title, o.text])

## Builds a quest's plans, step by step, onto `placements`; returns false (with a failure noted) if a piece can't go
## where its plan says.
func _build(q: Dictionary, placements: Array) -> bool:
	var steps: Array = q.objectives.filter(func(o): return o.has("plan"))
	steps.sort_custom(func(a, b): return QuestEngine.stage_of(a) < QuestEngine.stage_of(b))
	for o in steps:
		var zone := Data.zone(String(o.get("zone", "")))
		for pl in Plans.lay_out(o.plan, zone, placements):
			var y := BuildGrid.suggest_bottom(pl.id, pl.i, pl.k, int(pl.r), 10.0, placements, zone)
			if absf(y - float(pl.y)) > 0.01:
				t.ok(false, "%s: the ghost %s at (%d, %d) sits at %.2f, but builds at %.2f" % [q.id, pl.id, pl.i, pl.k, pl.y, y]); return false
			pl.uid = placements.size() + 1
			var v := BuildGrid.validate_placement(pl, {"placements": placements, "zones": Data.layout.zones, "statics": statics, "bodies": [], "flags": {}})
			if not v.ok:
				t.ok(false, "%s: %s at (%d, %d) turned %d can't be built: %s" % [q.id, pl.id, pl.i, pl.k, pl.r, v.reason]); return false
			placements.append(pl)
		t.ok(_done(o, placements), "%s: building its plan finishes \"%s\"" % [q.title, o.text])
	return true

func _done(o: Dictionary, placements: Array) -> bool:
	match o.kind:
		"room": return Validate.room_checklist(Data.zone(o.zone), placements, o.needs).all(func(r): return r.ok)
		"pieces":
			var n := Validate.pieces_in_zone(Data.zone(o.zone), placements).filter(func(p): return o.any.has(p.id)).size()
			return n >= int(o.count)
		"build":
			var F: Dictionary = Data.layout.get("fountain", {})
			var inlets: Array = [{"id": "fountain", "cell": F.inlet.cell, "side": F.inlet.side, "type": "water"}] if F.has("inlet") else []
			var mech := Mechanics.solve(placements, inlets)
			match String(o.check):
				"fountain": return mech.fed.get("fountain", false)
				"lamp": return not mech.lamps.is_empty()
				"bridge", "dock":
					var w := WalkWorld.new(statics, func(_f): return false)
					w.surfaces = BuildGrid.surfaces_for(placements)
					return Validate.path_across(Data.zone(String(o.zone)), w).ok
	return false

func test_the_plans_work():
	for id in ["bridge", "workshop", "fountain", "home", "dock", "lamp"]:
		_build(Data.quest(id), [])
	# the lamp's plan works beside a fountain built to its plan, and the farmhouse's bed fits the house
	var piazza: Array = []
	_build(Data.quest("fountain"), piazza)
	_build(Data.quest("lamp"), piazza)

func test_plan_ghosts_and_what_is_built():
	var pls := Plans.lay_out([[0, -18, "bridgePost"], [0, -18, "bridgeDeck"]], Data.zone("bridge"))
	t.ok(float(pls[1].y) > float(pls[0].y) + 0.1, "the deck's ghost rests on its post's")
	var rail := {"id": "railing", "i": 0.0, "k": -17.0, "r": 3, "y": 0.0}
	t.ok(Plans.built(rail, [{"id": "railing", "i": 0.0, "k": -17.0, "r": 3}]), "a railing on that edge is the one in the plan")
	t.ok(not Plans.built(rail, [{"id": "railing", "i": 0.0, "k": -17.0, "r": 1}]), "one on the other edge isn't")
	var s := GameState.new_game()
	var e := QuestEngine.new(s)
	s.quests["bridge"] = {"status": "active", "progress": {"wood": 10}}
	e.invalidate()
	var now := Plans.current(e)
	t.ok(now.size() == 1 and now[0].objective == "build", "with the wood gathered, the crossing's plan shows (not yet the railings')")
