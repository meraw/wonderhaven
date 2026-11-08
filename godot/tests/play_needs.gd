extends "res://tests/full_base.gd"

var papers: Array = []
var banners: Array = []

const PIECE := {"seat": "bench", "green": "hedge", "light": "lamp"}

func spot_in(h: Dictionary, id: String) -> Dictionary:
	var ctx: Dictionary = game.placement_ctx()
	var zone := BuildGrid.zone_at(ctx.zones, floor(float(h.x)), floor(float(h.z)))
	var cands: Array = []
	for di in range(-4, 5):
		for dk in range(-4, 5): cands.append(Vector2(floor(float(h.x)) + di, floor(float(h.z)) + dk))
	cands.sort_custom(func(a, b): return a.distance_to(Vector2(h.x, h.z)) < b.distance_to(Vector2(h.x, h.z)))
	for c in cands:
		var probe := {"uid": -1, "id": id, "i": c.x, "k": c.y, "r": 0, "y": BuildGrid.suggest_bottom(id, c.x, c.y, 0, 10.0, game.state.placements, zone)}
		if not Needs.inside(probe, h) or not BuildGrid.validate_placement(probe, ctx).ok: continue
		if Needs.reachable(probe, String(Needs.provides(id)[0]), game.reach_cache.get(String(h.id), [])): return probe
	return {}

func label_text(root: Node, name: String) -> String:
	var n: Node = root.find_child(name, true, false)
	if n == null: return ""
	var out := ""
	for l in ([n] + n.find_children("*", "", true, false)):
		if l is Label or l is Label3D: out += l.text + " | "
	return out

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}, "done": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen"]: s.flags[fl] = true
	s.tutorial = Tutorial.new_state(false, true); game.hud.apply_reveals()
	for b in ["lamp", "flowerBed"]: if not s.blueprints.has(b): s.blueprints.append(b)
	s.inventory.merge({"wood": 30, "crystal": 4, "flowers": 6, "coins": 50}, true)
	s.time.minute = 16 * 60.0
	game.render_resources()
	game.game_event.connect(func(type, data): if type == "paper": papers.append(data))
	await frames(10)
	var hs := Needs.hangouts()
	check("v1", "Monteforchetta has places that want things, and nothing is asked before the first morning", hs.size() >= 5 and Needs.open_keys(s, Needs.met_keys(game.village_score)).is_empty(), "%d hangouts" % hs.size())
	var b := feature("benchSquare")
	game.player.teleport(b.x, b.z + 1.6, PI); game.cam.snap(); await frames(5)
	var slept := await sleep_night()
	await frames(30)
	var open := Needs.open_keys(s, Needs.met_keys(game.village_score))
	var paper: Dictionary = papers[-1] if not papers.is_empty() else {}
	var notes: Array = paper.get("notes", [])
	await shot("paper-with-needs")
	check("v2", "The morning paper says what the village has noticed: three things it could use", slept and open.size() == 3 and notes.size() >= 3 and String(notes[0]).begins_with("Noticed:"), "%s / %s" % [str(open), str(notes)])
	var markers: int = game.need_root.get_child_count() if game.need_root else 0
	var tracked := label_text(game.hud.tracker, "village_needs")
	check("v3", "Icons float over the places that want something, and the tracker lists them", markers > 0 and tracked.contains("could use"), "%d markers; %s" % [markers, tracked])
	var first := true
	for kind in PIECE:
		await play_kind(String(kind), hs, open, first)
		first = false

func target_for(kind: String, hs: Array) -> Dictionary:
	for h in hs:
		if not h.get("needs", []).has(kind): continue
		if not spot_in(h, String(PIECE[kind])).is_empty(): return h
	return {}

func play_kind(kind: String, hs: Array, open: Array, first: bool) -> void:
	var s: Dictionary = game.state
	var piece: String = PIECE[kind]
	var h := target_for(kind, hs)
	var target := Needs.key(h, kind) if not h.is_empty() else kind
	if h.is_empty():
		check("v5-" + kind, "There is a place that wants a %s and room to build one there" % piece, false, "none found")
		return
	if not Needs.open_keys(s, Needs.met_keys(game.village_score)).has(target):
		Needs.know(s, [target]); game.render_needs(); game.hud.render_tracker()
	note("building %s for %s (%s by the morning roll)" % [piece, target, "noticed" if open.has(target) else "not noticed"])
	var zone_id := String(BuildGrid.zone_at(game.placement_ctx().zones, floor(float(h.x)), floor(float(h.z))).get("id", "village"))
	await walk_to(float(h.x), float(h.z), 2.0)
	await open_build(zone_id)
	if first:
		var rings: int = game.build.hangout_root.get_child_count()
		await shot("hangouts-in-build-mode")
		var hl := label_text(game.build.hangout_root, "hangout_" + String(h.id))
		check("v4", "In build mode each place shows its area, its name and what it wants", game.build.hangout_root.visible and rings >= hs.size() * 2 and hl.contains(String(h.name)), "%d nodes, visible=%s, label '%s'" % [rings, game.build.hangout_root.visible, hl])
	var spot := spot_in(h, piece)
	var before := int(s.harmony)
	var vp_before := int(s.village_points)
	var uids: Array = s.placements.map(func(p): return int(p.uid))
	await select_piece(piece)
	await place_anchored(float(spot.get("i", 0)), float(spot.get("k", 0)), 0)
	await frames(10)
	var placed: Dictionary = {}
	for p in s.placements:
		if p.id == piece and not uids.has(int(p.uid)): placed = p
	var at_spot: bool = not placed.is_empty() and is_equal_approx(float(placed.i), float(spot.get("i", INF))) and is_equal_approx(float(placed.k), float(spot.get("k", INF)))
	var met := Needs.met_keys(game.village_score).has(target)
	var gained := int(s.harmony) - before
	await shot("need-met-" + kind)
	check("v5-" + kind, "Building a %s where it was aimed meets the need: approval goes up by at least its %d points" % [piece, int(Data.needs.points)], at_spot and met and gained >= int(Data.needs.points), "%s for %s, aimed at %s, built %s: +%d" % [piece, target, str(spot), str(placed), gained])
	var h_built := int(s.harmony)
	var vp_built := int(s.village_points)
	await leave_build()
	await tap(KEY_P); await frames(8)
	var why := label_text(game.panels, "approval_why")
	var card := label_text(game.panels, "why_" + String(h.id))
	await shot("why-panel-" + kind)
	check("v6-" + kind, "The approval screen says why: the village's share, and this place's need met", why.contains("from the village") and card.contains("✔ " + String(Needs.kind_def(kind).get("name", ""))), "%s / %s" % [why, card])
	await tap(KEY_ESCAPE); await frames(5)
	await open_build(zone_id)
	if not placed.is_empty():
		var bb := BuildGrid.bounds(placed)
		game.build.focus = Vector3((bb.minX + bb.maxX) / 2.0, 0.0, (bb.minZ + bb.maxZ) / 2.0); await settle()
		mouse_move(game.camera.unproject_position(Vector3((bb.minX + bb.maxX) / 2.0, (float(bb.bottom) + float(bb.top)) / 2.0, (bb.minZ + bb.maxZ) / 2.0))); await frames(4)
		await tap(KEY_DELETE); await frames(8)
	var gone: bool = not placed.is_empty() and s.placements.filter(func(p): return int(p.uid) == int(placed.uid)).is_empty()
	var lost := not Needs.met_keys(game.village_score).has(target)
	check("v7-" + kind, "Taking the %s away loses the village's points (the first-of-its-kind bonus stays), the need is open again, and the best approval stays" % piece, gone and lost and int(s.village_points) == vp_before and int(s.harmony) == h_built - (vp_built - vp_before) and int(s.approval_best) >= h_built and Needs.open_keys(s, Needs.met_keys(game.village_score)).has(target),
		"removed=%s, approval %d (built %d, before %d), village %d (was %d), best %d" % [gone, int(s.harmony), h_built, before, int(s.village_points), vp_before, int(s.approval_best)])
	await tap(KEY_G); await frames(3)
	await select_piece(piece)
	await place_anchored(float(spot.get("i", 0)), float(spot.get("k", 0)), 0)
	await frames(6)
	var bar := label_text(game.build.ui, "draft_panel")
	await shot("draft-preview-" + kind)
	check("v8-" + kind, "Drafted there, the draft bar previews the approval the %s would bring" % piece, Drafts.of(s).size() == 1 and bar.contains("💖") and bar.contains("+"), bar)
	await tap(KEY_G); await frames(3)
	await ui_click("draft_build"); await frames(10)
	check("v9-" + kind, "Building the drafted %s meets the need again" % piece, Drafts.of(s).is_empty() and Needs.met_keys(game.village_score).has(target) and int(s.harmony) - before >= int(Data.needs.points), "approval %d (before %d)" % [int(s.harmony), before])
	await leave_build()
