extends RefCounted
var t
var statics: Array

const BRIEFS := ["bridge", "workshop", "fountain", "home", "dock", "lamp", "stones", "tables", "stall", "corner"]

func _init() -> void:
	statics = WorldStatics.build_statics(WorldStatics.generate_decor())

func _brief(qid: String) -> Dictionary:
	for o in Data.quest(qid).objectives:
		if String(o.get("kind", "")) == "commission": return o
	return {}

func _plan(o: Dictionary) -> Array:
	var out: Array = []
	for pl in Plans.lay_out(o.plan, Data.zone(String(o.get("zone", ""))), []):
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
	for qid in ["bridge", "workshop", "home", "dock", "stones", "tables", "stall", "corner"]:
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

func test_every_monteforchetta_building_request_is_a_brief():
	var briefs: Array = Data.quests.filter(func(q): return Data.quest_island(String(q.id)) == "hearthglow" and q.objectives.any(func(o): return String(o.get("kind", "")) == "commission")).map(func(q): return String(q.id))
	t.ok(briefs.size() >= 10 and BRIEFS.all(func(id): return briefs.has(id)), "ten briefs to build in Monteforchetta: %s" % str(briefs))
	t.ok(not Data.quests.any(func(q): return Data.quest_island(String(q.id)) == "hearthglow" and q.objectives.any(func(o): return String(o.get("kind", "")) in ["build", "room", "pieces"])), "no old-style building steps left there")
	var anywhere: Array = BRIEFS.filter(func(id): return Commission.anywhere(_brief(id)))
	t.ok(anywhere.size() >= 2, "some can go anywhere in the village (%s)" % str(anywhere))

func test_a_brief_at_a_hangout_counts_what_stands_there():
	var o := _brief("tables")
	var near: Array = _plan(o)
	t.ok(Commission.evaluate(o, {"placements": near}).done, "the example tables outside the bakery meet it")
	var far: Array = near.map(func(p):
		var q: Dictionary = p.duplicate()
		q.i = float(q.i) + 30.0
		return q)
	t.ok(not Commission.evaluate(o, {"placements": far}).done, "the same tables across the village don't")
	t.eq(Commission.site_text(o), "outside the bakery", "the site reads as the place")

func test_anywhere_means_anywhere_but_together():
	var o := _brief("stall")
	var counter := {"uid": 1, "id": "counter", "i": 20.0, "k": 10.0, "r": 0, "y": 0.0}
	var hedges := [{"uid": 2, "id": "hedge", "i": 5.0, "k": 15.0, "r": 0, "y": 0.0}, {"uid": 3, "id": "hedge", "i": 6.0, "k": 15.0, "r": 0, "y": 0.0}]
	var apart := Commission.evaluate(o, {"placements": [counter] + hedges})
	t.ok(not apart.done and apart.met == 1, "a counter here and hedges over there aren't one stall (%d of 2)" % apart.met)
	var moved := hedges.map(func(h):
		var q: Dictionary = h.duplicate()
		q.i = float(q.i) + 14.0 if int(q.uid) == 2 else 22.0
		q.k = 10.0
		return q)
	var together := Commission.evaluate(o, {"placements": [counter] + moved + [{"uid": 9, "id": "stoneBlock", "i": -20.0, "k": 0.0, "r": 0, "y": 0.0}]})
	t.ok(together.done and together.uids.size() == 3 and not together.uids.has(9), "put together, anywhere, they are; a block across the village isn't part of it")
	t.eq(Commission.site_text(o), "anywhere in the village", "and it says so")

const BOCCAPIOPPO := {"river_town_bridge": "build", "river_town_piazza": "power", "river_town_dancehall": "hall", "river_town_levee": "wall", "river_town_houseboat": "slipway", "river_town_houseboat/cosy": "cosy"}
const WISHED := {
	"build": [[28, 13, "railing", 2], [30, 13, "railing", 2], [32, 13, "railing", 2], [34, 13, "railing", 2], [25, 13, "lamp", 0]],
	"power": [[24, 3, "lamp", 0], [24, 7, "bench", 0]],
	"hall": [],
	"wall": [[1, 22, "lamp", 0], [1, 23, "bench", 0]],
	"slipway": [[-24, 32, "railing", 1], [-24, 33, "railing", 1], [-25, 32, "lamp", 0]],
	"cosy": []}

func _step(qid: String, oid: String) -> Dictionary:
	for o in Data.quest(qid).objectives:
		if String(o.id) == oid: return o
	return {}

func _built(o: Dictionary, entries: Array, placements: Array, here: Array) -> String:
	var zone := Data.zone(String(o.get("zone", "")))
	for pl in Plans.lay_out(entries, zone, placements):
		pl.y = BuildGrid.suggest_bottom(pl.id, pl.i, pl.k, int(pl.r), 10.0, placements, zone)
		pl.uid = placements.size() + 1
		var v := BuildGrid.validate_placement(pl, {"placements": placements, "zones": Data.layout.zones, "statics": here, "bodies": [], "flags": {}})
		if not v.ok: return "%s at (%d, %d): %s" % [pl.id, pl.i, pl.k, v.reason]
		placements.append(pl)
	return ""

func _here_world(placements: Array, here: Array) -> Dictionary:
	var m := Mechanics.solve(placements, Data.layout.get("machines", []))
	var path := func(zone_id: String) -> Dictionary:
		var w := WalkWorld.new(here, func(_f): return false)
		w.floors = WorldStatics.floors()
		w.surfaces = BuildGrid.surfaces_for(placements)
		return Validate.path_across(Data.zone(zone_id), w)
	return {"placements": placements, "lamps": m.lamps, "fed": m.fed, "mech": m, "path": path}

func test_every_boccapioppo_building_request_is_a_brief():
	var mine: Array = Data.quests.filter(func(q): return Data.quest_island(String(q.id)) == "river_town")
	t.ok(not mine.any(func(q): return q.objectives.any(func(o): return String(o.get("kind", "")) in ["build", "room", "pieces"])), "no old-style building steps left in Boccapioppo")
	var people: Array = Data.npcs.filter(func(n): return n.get("island", "") == "river_town").map(func(n): return String(n.id))
	for key in BOCCAPIOPPO:
		var o := _step(String(key).get_slice("/", 0), String(BOCCAPIOPPO[key]))
		t.ok(String(o.get("kind", "")) == "commission", "%s is a brief" % key)
		t.ok(o.musts.size() >= 1 and o.musts.size() <= 3 and o.get("wishes", []).size() <= 3, "%s: %d musts and %d wishes, three at most" % [key, o.musts.size(), o.get("wishes", []).size()])
		for c in o.musts + o.get("wishes", []):
			t.ok(Commission.KINDS.has(String(c.check)) and String(c.get("label", "")) != "", "%s: \"%s\" is a known check with a label" % [key, c.get("label", "")])
		t.ok(o.get("wishes", []).size() >= 2, "%s: someone in town wants something of it" % key)
		for c in o.get("wishes", []):
			t.ok(people.has(String(c.get("who", ""))), "%s: \"%s\" is wished by someone who lives in Boccapioppo" % [key, c.label])
		var before: Array = []
		for q in Data.quests.filter(func(x): return Data.quest_island(String(x.id)) == "hearthglow" and x.get("main", false)):
			for oo in q.objectives:
				if String(oo.get("kind", "")) == "commission": before.append_array(Commission.kinds_of(oo) + Commission.kinds_of(oo, "wishes"))
		for a in _ancestors(String(key).get_slice("/", 0)):
			for oo in Data.quest(a).objectives:
				if String(oo.get("kind", "")) == "commission": before.append_array(Commission.kinds_of(oo) + Commission.kinds_of(oo, "wishes"))
		var fresh: Array = (Commission.kinds_of(o) + Commission.kinds_of(o, "wishes")).filter(func(k): return not before.has(k) and not Commission.BASIC.has(k))
		var unique := {}
		for k in fresh: unique[k] = true
		t.ok(unique.size() <= 1, "%s brings in at most one new kind of check (%s)" % [key, str(unique.keys())])

func test_boccapioppos_plans_meet_the_musts_and_every_wish_can_be_met():
	Data.use_island("river_town")
	for key in BOCCAPIOPPO:
		var o := _step(String(key).get_slice("/", 0), String(BOCCAPIOPPO[key]))
		Data.apply_world_flags({"river_town_launched": true} if String(o.id) == "cosy" else {})
		var here := WorldStatics.build_statics(WorldStatics.generate_decor())
		var placements: Array = []
		var problem := _built(o, o.plan, placements, here)
		t.eq(problem, "", "%s: its example plan can be built" % key)
		var r := Commission.evaluate(o, _here_world(placements, here))
		t.ok(r.done, "%s: its example plan meets every must: %s" % [key, str(r.musts.map(func(m): return "%s %s" % [m.label, m.ok]))])
		problem = _built(o, WISHED[String(o.id)], placements, here)
		t.eq(problem, "", "%s: the pieces for its wishes can be built too" % key)
		r = Commission.evaluate(o, _here_world(placements, here))
		t.ok(r.done and r.wishes.all(func(w): return w.ok), "%s: every wish met together: %s" % [key, str(r.wishes.map(func(w): return "%s %s" % [w.label, w.ok]))])
	Data.apply_world_flags({})
	Data.use_island("hearthglow")

func test_a_sealed_check_wants_the_breach_closed():
	Data.use_island("river_town")
	var o := _step("river_town_levee", "wall")
	var empty := Commission.evaluate(o, {"placements": []})
	t.ok(not empty.done and not empty.musts[0].ok, "an open breach isn't sealed")
	var placements: Array = []
	_built(o, o.plan, placements, WorldStatics.build_statics(WorldStatics.generate_decor()))
	t.ok(Commission.evaluate(o, {"placements": placements}).done, "the wall across it is")
	Data.use_island("hearthglow")

const CASALRANA := ["rice_village_flat/furnish", "rice_village_stairs/climb", "rice_village_nativity/stable", "rice_village_train/platform", "rice_village_train/shelter",
	"rice_village_water/sluice", "rice_village_water/walk", "rice_village_water/paddy", "rice_village_mill/drive", "rice_village_bench/build"]
const CASALRANA_FLAGS := {"rice_village_flat/furnish": {"rice_village_roofPatched": true}, "rice_village_water/paddy": {"rice_village_canalFull": true}, "rice_village_mill/drive": {"rice_village_canalFull": true}}
const CASALRANA_BUILT := {
	"rice_village_flat/furnish": [[14, -40, "bed", 0], [17, -39, "table", 0], [17, -38, "chair", 2]],
	"rice_village_stairs/climb": [[-16, 8, "stoneBlock", 0], [-16, 8, "stairs", 0], [-16, 9, "stairs", 0]],
	"rice_village_nativity/stable": [[-15, 0, "pillar", 0], [-14, 0, "pillar", 0], [-15, 0, "roof", 0], [-16, 1, "lamp", 0], [-13, 1, "lamp", 0]],
	"rice_village_train/platform": [[10, -43, "bridgeDeck", 0], [11, -43, "bridgeDeck", 0], [12, -43, "bridgeDeck", 0], [13, -43, "bridgeDeck", 0],
		[17, -43, "bridgeDeck", 0], [18, -43, "bridgeDeck", 0], [19, -43, "bridgeDeck", 0], [20, -43, "bridgeDeck", 0],
		[25, -43, "bridgeDeck", 0], [26, -43, "bridgeDeck", 0], [27, -43, "bridgeDeck", 0], [28, -43, "bridgeDeck", 0]],
	"rice_village_train/shelter": [[29, -44, "pillar", 0], [30, -44, "pillar", 0], [31, -44, "lamp", 0], [29, -44, "roof", 0], [29, -42, "bench", 0], [31, -42, "lamp", 0], [32, -42, "enamelSign", 0]],
	"rice_village_water/sluice": [[-43, -28, "pillar", 0], [-38, -28, "pillar", 0], [-38, -30, "lever", 0]],
	"rice_village_water/walk": [[-43, -29, "bridgeDeck", 0], [-42, -29, "bridgeDeck", 0], [-41, -29, "bridgeDeck", 0], [-38, -29, "bridgeDeck", 0], [-39, -29, "bridgeDeck", 0], [-40, -29, "bridgeDeck", 0]],
	"rice_village_water/paddy": [[-39, 10, "waterwheel", 1], [-38, 10, "pump", 2], [-37, 10, "pipe", 1], [-36, 10, "pipe", 1], [-35, 10, "pipe", 1], [-34, 10, "pipe", 1]],
	"rice_village_mill/drive": [[-39, -13, "waterwheel", 1], [-38, -13, "shaft", 1], [-37, -13, "shaft", 1], [-36, -13, "shaft", 1], [-35, -13, "shaft", 1], [-34, -13, "shaft", 1], [-33, -13, "shaft", 1]],
	"rice_village_bench/build": [[9, 35, "bench", 0], [11, 35, "flowerBed", 0]]}
const CASALRANA_WISHED := {
	"rice_village_flat/furnish": [[15, -38, "rug", 0], [20, -40, "lamp", 0]],
	"rice_village_stairs/climb": [[-14, 9, "lamp", 0], [-14, 8, "railing", 0]],
	"rice_village_nativity/stable": [[-17, 3, "fence", 0], [-16, 3, "fence", 0], [-13, 3, "bench", 0]],
	"rice_village_train/platform": [[8, -44, "flowerBed", 0], [15, -44, "flowerBed", 0], [22, -44, "railLantern", 0]],
	"rice_village_train/shelter": [[33, -44, "flowerBed", 0, "ff8fab"]],
	"rice_village_water/sluice": [[-37, -27, "fence", 0], [-36, -27, "fence", 0], [-37, -30, "lamp", 0]],
	"rice_village_water/walk": [[-42, -29, "railing", 0], [-41, -29, "railing", 0], [-45, -27, "bench", 0]],
	"rice_village_water/paddy": [[-36, 12, "lever", 0], [-36, 8, "flowerBed", 0]],
	"rice_village_mill/drive": [[-35, -11, "lamp", 0], [-37, -11, "workbench", 0]],
	"rice_village_bench/build": [[8, 35, "flowerBed", 0], [12, 36, "lamp", 0]]}

func _cr_step(key: String) -> Dictionary: return _step(key.get_slice("/", 0), key.get_slice("/", 1))

func test_every_casalrana_building_request_is_a_brief():
	var mine: Array = Data.quests.filter(func(q): return Data.quest_island(String(q.id)) == "rice_village")
	t.ok(not mine.any(func(q): return q.objectives.any(func(o): return String(o.get("kind", "")) in ["build", "room", "pieces"])), "no old-style building steps left in Casalrana")
	var people: Array = Data.npcs.filter(func(n): return n.get("island", "") == "rice_village" and not n.get("visitor", false)).map(func(n): return String(n.id))
	var before: Array = []
	for q in Data.quests.filter(func(x): return Data.quest_island(String(x.id)) in ["hearthglow", "river_town"] and x.get("main", false)):
		for oo in q.objectives:
			if String(oo.get("kind", "")) == "commission": before.append_array(Commission.kinds_of(oo) + Commission.kinds_of(oo, "wishes"))
	for key in CASALRANA:
		var o := _cr_step(key)
		t.ok(String(o.get("kind", "")) == "commission", "%s is a brief" % key)
		if String(o.get("kind", "")) != "commission": continue
		var most := 4 if key == "rice_village_train/shelter" else 3
		t.ok(o.musts.size() >= 1 and o.musts.size() <= most and o.get("wishes", []).size() >= 2 and o.get("wishes", []).size() <= 3, "%s: %d musts (the inspector's shelter has his four) and %d wishes" % [key, o.musts.size(), o.get("wishes", []).size()])
		for c in o.musts + o.get("wishes", []):
			t.ok(Commission.KINDS.has(String(c.check)) and String(c.get("label", "")) != "", "%s: \"%s\" is a known check with a label" % [key, c.get("label", "")])
		for c in o.get("wishes", []):
			t.ok(people.has(String(c.get("who", ""))), "%s: \"%s\" is wished by someone who lives in Casalrana" % [key, c.label])
		var fresh: Array = (Commission.kinds_of(o) + Commission.kinds_of(o, "wishes")).filter(func(k): return not before.has(k) and not Commission.BASIC.has(k))
		t.ok(fresh.is_empty(), "%s uses only checks you've met before (%s)" % [key, str(fresh)])

func test_casalranas_briefs_can_be_built_and_every_wish_met_with_pieces_you_have():
	Data.use_island("rice_village")
	var known: Array = Progress.as_if_played(["hearthglow", "river_town"], "rice_village", "Pip").blueprints
	for q in Data.quests.filter(func(x): return Data.quest_island(String(x.id)) == "rice_village"):
		known.append_array(q.get("onAccept", {}).get("blueprints", []))
	for key in CASALRANA:
		var o := _cr_step(key)
		Data.apply_world_flags(CASALRANA_FLAGS.get(key, {}))
		var here := WorldStatics.build_statics(WorldStatics.generate_decor())
		var placements: Array = []
		var problem := _built(o, CASALRANA_BUILT[key], placements, here)
		t.eq(problem, "", "%s: the playthrough's build can be built" % key)
		var r := Commission.evaluate(o, _here_world(placements, here))
		t.ok(r.done, "%s: it meets every must: %s" % [key, str(r.musts.map(func(m): return "%s %s" % [m.label, m.ok]))])
		problem = _built(o, CASALRANA_WISHED[key], placements, here)
		t.eq(problem, "", "%s: the pieces for its wishes can be built too" % key)
		r = Commission.evaluate(o, _here_world(placements, here))
		t.ok(r.done and r.wishes.all(func(w): return w.ok), "%s: every wish met together: %s" % [key, str(r.wishes.map(func(w): return "%s %s" % [w.label, w.ok]))])
		for e in CASALRANA_BUILT[key] + CASALRANA_WISHED[key]:
			t.ok(known.has(String(e[2])), "%s: you have the plans for the %s" % [key, e[2]])
	Data.apply_world_flags({})
	Data.use_island("hearthglow")
