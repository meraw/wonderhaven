extends RefCounted
var t

func _pl(uid: int, id: String, i: int, k: int, r: int) -> Dictionary:
	return {"uid": uid, "id": id, "i": float(i), "k": float(k), "r": r, "y": BuildGrid.suggest_bottom(id, float(i), float(k), r, 10.0, [], {})}

func _inlets() -> Array: return Data.layout.get("machines", [])

func test_a_waterwheel_says_whether_it_turns_where_you_hold_it():
	Data.use_island("rice_village")
	var in_canal := Mechanics.explain(_pl(1, "waterwheel", -39, 10, 1), [], _inlets())
	t.ok(in_canal.ok, "in the canal the wheel turns")
	t.ok(String(in_canal.text).contains("east and west"), "and says its axle sends power east and west: %s" % in_canal.text)
	var on_bank := Mechanics.explain(_pl(1, "waterwheel", -36, 10, 1), [], _inlets())
	t.ok(not on_bank.ok and String(on_bank.text).contains("flowing water"), "on the bank it says it needs flowing water: %s" % on_bank.text)
	Data.use_island("hearthglow")

func test_a_pump_says_which_side_takes_power_and_where_the_water_comes_out():
	Data.use_island("rice_village")
	var wheel := _pl(1, "waterwheel", -39, 10, 1)
	var right := Mechanics.explain(_pl(2, "pump", -38, 10, 2), [wheel], _inlets())
	t.ok(right.ok and String(right.text).contains("east side"), "turned with its power side to the wheel it pumps out of its east side: %s" % right.text)
	var wrong := Mechanics.explain(_pl(2, "pump", -38, 10, 0), [wheel], _inlets())
	t.ok(not wrong.ok and String(wrong.text).contains("no power") and String(wrong.text).contains("east side"), "turned the other way it says its east side takes the power: %s" % wrong.text)
	var far := Mechanics.explain(_pl(2, "pump", -36, 10, 2), [], _inlets())
	t.ok(not far.ok and String(far.text).contains("no power"), "away from any wheel it has no power: %s" % far.text)
	Data.use_island("hearthglow")

func test_pipes_say_when_they_are_dry_and_the_last_one_feeds_the_paddy():
	Data.use_island("rice_village")
	var built: Array = [_pl(1, "waterwheel", -39, 10, 1), _pl(2, "pump", -38, 10, 2)]
	var across := Mechanics.explain(_pl(3, "pipe", -37, 10, 0), built, _inlets())
	t.ok(not across.ok and String(across.text).contains("north and south"), "a pipe lying north to south beside the spout is dry and says which ends it has: %s" % across.text)
	var along := Mechanics.explain(_pl(3, "pipe", -37, 10, 1), built, _inlets())
	t.ok(along.ok and (along.feeds as Array).is_empty(), "turned east to west it carries the water, not yet to the inlet")
	for i in [-37, -36, -35]: built.append(_pl(10 + i, "pipe", i, 10, 1))
	var last := Mechanics.explain(_pl(9, "pipe", -34, 10, 1), built, _inlets())
	t.ok(last.ok and (last.feeds as Array).has("The winter paddy's inlet"), "the last pipe brings the water to the winter paddy's inlet: %s" % str(last.feeds))
	Data.use_island("hearthglow")

func test_a_machine_turned_the_wrong_way_is_not_the_plans_piece():
	var planned := {"id": "waterwheel", "i": -39.0, "k": 10.0, "r": 1, "y": 0.0}
	t.ok(not Plans.built(planned, [{"id": "waterwheel", "i": -39.0, "k": 10.0, "r": 0}]), "a wheel with its axle along the canal isn't the plan's")
	t.ok(Plans.built(planned, [{"id": "waterwheel", "i": -39.0, "k": 10.0, "r": 3}]), "turned half round its axle still points the same way: it is")
	var pump := {"id": "pump", "i": -38.0, "k": 10.0, "r": 2, "y": 0.0}
	t.ok(not Plans.built(pump, [{"id": "pump", "i": -38.0, "k": 10.0, "r": 0}]), "a pump with its spout towards the wheel isn't")

func test_a_mills_checklist_asks_for_shafts_not_a_pump_and_counts_only_its_own_site():
	Data.use_island("rice_village")
	var paddy_kit: Array = [_pl(1, "waterwheel", -39, 10, 1), _pl(2, "pump", -38, 10, 2)]
	var solved := Mechanics.solve(paddy_kit, _inlets())
	var mill := Mechanics.fed_steps("power", Data.zone("rice_village_mill"), paddy_kit, solved)
	t.eq(mill.size(), 2, "a power target: a turning wheel, then shafts")
	t.ok(not mill[0].ok, "the paddy's wheel, on another site, doesn't tick the mill's")
	t.ok(String(mill[1].label).contains("shafts") and not mill.any(func(r): return String(r.label).contains("pump")), "and it never asks for a pump")
	var paddy := Mechanics.fed_steps("water", Data.zone("rice_village_paddy"), paddy_kit, solved)
	t.ok(paddy[0].ok and paddy[1].ok and not paddy[2].ok, "at the paddy the wheel and the pump are ticked, the pipes still to do")
	Data.use_island("hearthglow")

func test_the_inlet_marker_sits_on_the_edge_it_names():
	Data.use_island("rice_village")
	var tg: Dictionary = _inlets()[0]
	var spot: Vector3 = MachineMarks.target_spot(tg)
	t.ok(absf(spot.x - (float(tg.cell[0]) + 1.0)) < 0.001 and absf(spot.z - (float(tg.cell[1]) + 0.5)) < 0.001, "the paddy's inlet arrow is on the east edge of its cell: %s" % spot)
	t.ok(MachineMarks.target_text(tg, false).contains("Water goes in here") and MachineMarks.target_text(tg, true).contains("Water arrives"), "and says what goes in, then that it arrived")
	var marks := MachineMarks.mark_spots({"id": "pump", "i": -38.0, "k": 10.0, "r": 2, "y": 0.0})
	var by_side := {}
	for m in marks: by_side[m.side] = m.type
	t.eq(by_side, {"E": "water", "W": "power"}, "a pump turned round shows its power mark west and its water mark east")
	Data.use_island("hearthglow")

func test_sides_read_as_words():
	t.eq(Mechanics.sides_text(["E", "W"]), "east and west", "two sides")
	t.eq(Mechanics.sides_text(["N", "E", "S", "W"]), "north, east, south and west", "four sides")
	t.eq(Mechanics.sides_text(["S"]), "south", "one side")
