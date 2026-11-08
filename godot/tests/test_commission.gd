extends RefCounted
var t
var statics: Array

const BRIEFS := ["bridge", "workshop", "fountain", "home", "dock", "lamp"]

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

func _brief(qid: String) -> Dictionary:
	for o in Data.quest(qid).objectives:
		if String(o.get("kind", "")) == "commission": return o
	return {}

func _plan(o: Dictionary) -> Array:
	var out: Array = []
	for pl in Plans.lay_out(o.plan, Data.zone(String(o.zone)), []):
		pl.uid = out.size() + 1
		out.append(pl)
	return out

func _world(placements: Array) -> Dictionary:
	var F: Dictionary = Data.layout.get("fountain", {})
	var targets: Array = [{"id": "fountain", "cell": F.inlet.cell, "side": F.inlet.side, "type": "water"}] if F.has("inlet") else []
	var m := Mechanics.solve(placements, targets)
	var path := func(zone_id: String) -> Dictionary:
		var w := WalkWorld.new(statics, func(_f): return false)
		w.floors = WorldStatics.floors()
		w.surfaces = BuildGrid.surfaces_for(placements)
		return Validate.path_across(Data.zone(zone_id), w)
	return {"placements": placements, "lamps": m.lamps, "fed": m.fed, "mech": m, "path": path}

func _ancestors(qid: String) -> Array:
	var out: Array = []
	var todo: Array = Data.quest(qid).get("requires", {}).get("quests", []).duplicate()
	while not todo.is_empty():
		var id := String(todo.pop_front())
		if out.has(id): continue
		out.append(id)
		todo.append_array(Data.quest(id).get("requires", {}).get("quests", []))
	return out

func test_monteforchettas_briefs_are_sound():
	for qid in BRIEFS:
		var o := _brief(qid)
		t.ok(not o.is_empty(), "%s's building step is a commission" % qid)
		if o.is_empty(): continue
		t.ok(o.musts.size() >= 1 and o.musts.size() <= 3, "%s: %d musts, no more than three" % [qid, o.musts.size()])
		t.ok(o.get("wishes", []).size() <= 3, "%s: no more than three wishes" % qid)
		for c in o.musts + o.get("wishes", []):
			t.ok(Commission.KINDS.has(String(c.check)) and String(c.get("label", "")) != "", "%s: \"%s\" is a known check with a label" % [qid, c.get("label", "")])
		for c in o.get("wishes", []):
			t.ok(not Data.npc(String(c.get("who", ""))).is_empty(), "%s: \"%s\" is wished by a villager" % [qid, c.label])
		var before: Array = []
		for a in _ancestors(qid):
			before.append_array(Commission.kinds_of(_brief(a)))
		var fresh: Array = Commission.kinds_of(o).filter(func(k): return not before.has(k) and not Commission.BASIC.has(k))
		t.ok(fresh.size() <= 1, "%s brings in at most one new kind of check (%s)" % [qid, str(fresh)])

func test_following_each_plan_meets_every_must():
	for qid in ["bridge", "workshop", "home", "dock"]:
		var o := _brief(qid)
		var r := Commission.evaluate(o, _world(_plan(o)))
		t.ok(r.done, "%s: its example plan meets every must: %s" % [qid, str(r.musts.map(func(m): return "%s %s" % [m.label, m.ok]))])
	var piazza := _plan(_brief("fountain"))
	t.ok(Commission.evaluate(_brief("fountain"), _world(piazza)).done, "the fountain's plan gets the water there")

func test_checks():
	var o := {"zone": "plaza"}
	var bench := {"uid": 1, "id": "bench", "i": 3.0, "k": 1.0, "r": 0, "y": 0.0}
	var chair := {"uid": 2, "id": "chair", "i": 6.0, "k": 1.0, "r": 0, "y": 0.0, "color": "#ff7aa8"}
	var block := {"uid": 3, "id": "stoneBlock", "i": 8.0, "k": 3.0, "r": 0, "y": 0.0}
	var outside := {"uid": 4, "id": "bench", "i": -20.0, "k": 20.0, "r": 0, "y": 0.0}
	var list := [bench, chair, block, outside]
	var ctx := {"placements": list}
	var seats := Commission.check({"check": "provides", "kind": "seat", "count": 2}, o, Commission.here(o, list), ctx)
	t.ok(seats.ok and seats.have == 2 and not seats.uids.has(4), "two seats in the piazza, the bench elsewhere doesn't count")
	var with := Commission.check({"check": "pieces", "any": ["bench", "chair"], "count": 2, "with": ["sofa"]}, o, Commission.here(o, list), ctx)
	t.ok(not with.ok and with.have == 2, "two seats, but not the sofa it has to include")
	t.ok(Commission.check({"check": "recolored"}, o, Commission.here(o, list), ctx).uids == [2], "the painted chair")
	var wood := Commission.check({"check": "material", "of": ["wood"]}, o, Commission.here(o, list), ctx)
	t.ok(not wood.ok and wood.have == 2 and wood.need == 3, "not all in wood: the stone block (%s)" % str(wood))
	t.ok(Commission.check({"check": "kinds", "count": 3}, o, Commission.here(o, list), ctx).ok, "three kinds of piece")
	t.eq(Commission.material("lamp"), "wood", "a lamp is mostly wood")
	t.eq(Commission.material("bed"), "wood", "lire don't count as a material")
	var stack := [{"uid": 5, "id": "stoneBlock", "i": 4.0, "k": 2.0, "r": 0, "y": 0.0}, {"uid": 6, "id": "stoneBlock", "i": 4.0, "k": 2.0, "r": 0, "y": 1.0}, {"uid": 7, "id": "chair", "i": 4.0, "k": 2.0, "r": 0, "y": 2.0}]
	var tall := Commission.check({"check": "taller", "height": 2.5}, o, stack, ctx)
	t.ok(tall.ok and tall.uids == [7], "a chair on two blocks is taller than two and a half metres, and the chair is the top")
	var lit := Commission.check({"check": "lit"}, o, [{"uid": 8, "id": "poweredLamp"}], {"lamps": {8: true}})
	t.ok(lit.ok and lit.uids == [8], "a lit electric lamp")
	t.ok(not Commission.check({"check": "path"}, {"zone": "bridge"}, [], {}).ok, "no walk world, no path")

func test_a_commission_is_done_when_its_musts_are_met_and_wishes_wait_for_hand_in():
	var s := GameState.new_game("Tester")
	s.island = "hearthglow"
	var e := QuestEngine.new(s)
	var o := _brief("bridge")
	s.quests["bridge"] = {"status": "active", "progress": {"wood": 14}}
	var list: Array = []
	e.world = func(): return _world(list)
	e.invalidate()
	t.ok(e.current_stage("bridge") == 1 and not e.objective("bridge", o).done, "the crossing's brief is open, nothing built")
	for pl in _plan(o).filter(func(p): return p.id != "railing"): list.append(pl)
	e.invalidate()
	var cr := e.commission("bridge", o)
	t.ok(cr.musts[0].ok and not cr.musts[1].ok and not e.objective("bridge", o).done, "walkable, but no railings yet")
	t.ok(not cr.musts[0].uids.is_empty(), "the planks that make the path are the ones it points at")
	var facts := {"quests": s.quests, "must": func(q, oid, i):
		e.invalidate()
		for ob in Data.quest(q).objectives:
			if String(ob.get("id", "")) == oid: return e.commission(q, ob).musts[i].ok
		return false}
	t.ok(Tutorial.is_done({"done": "must:bridge:build:0"}, facts) and not Tutorial.is_done({"done": "must:bridge:build:1"}, facts), "the guided day can wait on one must")
	for pl in _plan(o).filter(func(p): return p.id == "railing"):
		pl.uid = list.size() + 1
		list.append(pl)
	e.invalidate()
	e.refresh()
	t.ok(e.is_ready("bridge"), "with four railings every must is met: ready to hand in")
	t.ok(not e.commission("bridge", o).wishes[1].ok, "the Sindaco's eight railings are only a wish")
	list.clear()
	e.invalidate()
	t.ok(e.objective("bridge", o).done, "a met brief stays met")

func test_the_permit_stamp():
	var c := {"stamps": ["Approvato", "Approvato con plauso", "Approvato con lode"], "wish": {"harmony": 5, "hearts": 1}}
	var none := [{"ok": false, "who": "fern"}, {"ok": false, "who": "percival"}]
	var some := [{"ok": true, "who": "fern"}, {"ok": false, "who": "percival"}]
	var all := [{"ok": true, "who": "fern"}, {"ok": true, "who": "percival"}]
	t.eq(Commission.stamp(none, c).text, "Approvato", "the musts alone pass")
	t.eq(Commission.stamp(some, c).text, "Approvato con plauso", "a wish met gets a better stamp")
	t.eq(Commission.stamp(all, c).text, "Approvato con lode", "every wish gets the best")
	t.eq(Commission.stamp([], c).text, "Approvato", "a brief without wishes")
	var b := Commission.bonus(all, c)
	t.ok(b.harmony == 10 and b.hearts == {"fern": 1, "percival": 1}, "each wish met: approval, and a heart from whoever wished it")
