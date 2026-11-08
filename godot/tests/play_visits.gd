extends "res://tests/full_base.gd"

var visits: Array = []
var arrivals: Array = []

func cands(h: Dictionary) -> Array:
	var c := Vector2(float(h.x), float(h.z))
	var out: Array = []
	for di in range(-4, 5):
		for dk in range(-4, 5): out.append(Vector2(floor(c.x) + di, floor(c.y) + dk))
	out.sort_custom(func(a, b): return a.distance_to(c) < b.distance_to(c))
	return out

func put(id: String, i: float, k: float) -> Dictionary:
	var zone := BuildGrid.zone_at(game.placement_ctx().zones, i, k)
	var pl := {"uid": int(game.state.next_uid), "id": id, "i": i, "k": k, "r": 0, "y": BuildGrid.suggest_bottom(id, i, k, 0, 10.0, game.state.placements, zone)}
	game.state.next_uid = int(pl.uid) + 1
	return pl if game.commit_place(pl, false, false).ok else {}

func place_where(id: String, h: Dictionary, test: Callable) -> Dictionary:
	for c in cands(h):
		var pl := put(id, c.x, c.y)
		if pl.is_empty(): continue
		if Needs.inside(pl, h) and test.call(pl): return pl
		game.commit_remove(int(pl.uid), false)
	return {}

func usable(pl: Dictionary) -> bool: return game.visit_opts.any(func(o): return int(o.uid) == int(pl.uid) and o.use)

func agent_at(uid: int, seated: bool = false):
	for a in game.npcs.values():
		if a.visiting() and int(a.visit.uid) == uid and a.visit.get("arrived", false) and (not seated or a.seated()): return a
	return null

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}, "done": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen"]: s.flags[fl] = true
	s.tutorial = Tutorial.new_state(false, true); game.hud.apply_reveals()
	s.time.minute = 10 * 60.0
	game.shot_cfg["visit_rate"] = 6.0
	game.game_event.connect(func(type, data): if type == "visit": visits.append(data))
	game.game_event.connect(func(type, data): if type == "visit_arrived": arrivals.append(data))
	await frames(10)
	var hs := Needs.hangouts()
	check("w1", "Nothing built at the village's spots, nobody goes visiting", game.visit_opts.is_empty(), "%d options" % game.visit_opts.size())
	var church := Needs.hangout(hs, "church")
	var base := place_where("stoneBlock", church, func(p): return true)
	var top := put("stoneBlock", float(base.get("i", 0)), float(base.get("k", 0))) if not base.is_empty() else {}
	var chair := put("chair", float(base.get("i", 0)), float(base.get("k", 0))) if not top.is_empty() else {}
	await frames(5)
	check("w2", "A chair up on two blocks on the church steps is something to stare at", not chair.is_empty() and game.visit_opts.any(func(o): return int(o.uid) == int(chair.uid) and not o.use), str(chair))
	game.player.teleport(float(church.x) + 1.0, float(church.z) - 4.5, 0.0); game.cam.yaw = PI; game.cam.snap()
	var starer = null
	for n in 1500:
		starer = agent_at(int(chair.get("uid", -1)))
		if starer != null: break
		await frames(1)
	var stared: bool = starer != null
	await frames(5)
	await shot("puzzled-stare")
	check("w3", "Someone walks up to it, shrugs and stares, with a question mark", stared and starer.stare_mark.visible and not starer.visit.use, "%s" % (starer.def.name if starer else "nobody came"))
	var bakery := Needs.hangout(hs, "bakery")
	var bench := place_where("bench", bakery, usable)
	await frames(5)
	check("w4", "A bench outside the bakery with room in front can be sat on", not bench.is_empty() and usable(bench), str(bench))
	game.player.teleport(float(bakery.x) + 3.0, float(bakery.z) + 4.0, PI); game.cam.yaw = 0.3; game.cam.snap()
	var sitter = null
	for n in 2000:
		sitter = agent_at(int(bench.get("uid", -1)), true)
		if sitter != null: break
		await frames(1)
	var sat: bool = sitter != null
	await frames(10)
	await shot("sitting-on-your-bench")
	var seat := NapGags.seat_spot(bench) if not bench.is_empty() else Vector3.ZERO
	check("w5", "A villager comes along and sits on it", sat and sitter.character.hold == "sit" and Vector2(sitter.pos.x - seat.x, sitter.pos.z - seat.z).length() < 0.2, "%s" % (sitter.def.name if sitter else "nobody sat"))
	var rel: Dictionary = s.relationships.get(String(sitter.def.id), {}) if sitter else {}
	check("w6", "...and likes the Geometra a little more for it: a heart, once a day", int(rel.get("used_day", 0)) == int(s.time.day) and int(rel.get("hearts", 0)) >= 1, str(rel))
	if not bench.is_empty(): game.commit_remove(int(bench.uid), false)
	await frames(10)
	check("w7", "Take the bench away and they get up and go", sitter == null or not (sitter.visiting() and int(sitter.visit.uid) == int(bench.get("uid", -1))), "")
	var piazza := Needs.hangout(hs, "piazza")
	var built: Array = []
	for id in ["flowerBed", "flowerBed", "lamp", "lamp", "counter"]:
		var p := place_where(id, piazza, usable)
		if not p.is_empty(): built.append(p)
	await frames(5)
	var lively := Visits.level(game.village_score, "piazza")
	await tap(KEY_P); await frames(8)
	var card := ""
	var node: Node = game.panels.find_child("why_piazza", true, false)
	if node: for l in node.find_children("*", "Label", true, false): card += l.text + " | "
	await shot("lively-piazza-why")
	check("w8", "Flowers, lamps and a counter make the piazza fully lively, and the approval screen says so", built.size() == 5 and lively == 3 and card.contains("lively 3/3"), "%d pieces, level %d, %s" % [built.size(), lively, card])
	await tap(KEY_ESCAPE); await frames(5)
	s.time.minute = 20.5 * 60.0
	game.player.teleport(float(piazza.x) + 5.5, float(piazza.z) + 5.5, PI * 1.25); game.cam.yaw = 0.8; game.cam.snap()
	for a in game.npcs.values():
		if a.visiting(): a.end_visit()
		a.visit_t = 0.5
	await frames(30)
	var awake: Array = game.npcs.values().filter(func(a): return a.present and a.activity != "sleep")
	var gathered := 0
	for n in 2000:
		gathered = game.npcs.values().filter(func(a): return a.visiting() and String(a.visit.hangout) == "piazza" and a.visit.get("arrived", false)).size()
		if gathered >= mini(3, awake.size()): break
		await frames(1)
	var ok: bool = awake.size() > 0 and gathered >= mini(3, awake.size())
	await frames(10)
	await shot("dusk-gathering")
	check("w9", "At dusk, with the piazza fully lively, people gather there", ok and WorkDay.dusk(s.time, WorkDay.def(Data.island)), "%d gathered of %d awake (%s)" % [gathered, awake.size(), Clock.text(s.time)])
