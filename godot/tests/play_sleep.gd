extends "res://tests/full_base.gd"

var gags_seen: Array = []
var papers: Array = []

func get_up() -> void:
	if game.sitting.is_empty(): return
	key(KEY_W, true); await frames(2); key(KEY_W, false); await frames(4)

func last_toast() -> String:
	var n: int = game.toasts.get_child_count()
	if n == 0: return ""
	for l in game.toasts.get_child(n - 1).find_children("*", "Label", true, false): return l.text
	return ""

func at_bench() -> void:
	var b := feature("benchSquare")
	game.player.teleport(b.x, b.z + 1.6, PI); game.cam.yaw = 0.0; game.cam.snap(); await frames(5)
	await face_and_press("benchSquare", b.x, b.z); await frames(6)

func bench_nap(gag: String, button: String, minute: float) -> bool:
	game.shot_cfg["napgag"] = gag
	await get_up()
	await at_bench()
	var btn := game.panels.find_child(button, true, false) as Control
	if btn == null: note("no %s in the bench panel" % button); return false
	await click(btn.get_global_rect().get_center())
	for n in 300:
		await frames(1)
		if absf(game.state.time.minute - minute) < 1.0 and not game.sitting.is_empty(): break
	await frames(13)
	return not game.sitting.is_empty()

func wait_explore() -> void:
	for n in 100:
		if game.mode == "explore": return
		await frames(2)

func a_tree() -> Dictionary:
	for n in Data.layout.nodes:
		if n.kind == "chop" and game.actions.ready(n): return n
	return {}

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}, "done": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen"]: s.flags[fl] = true
	s.tutorial = Tutorial.new_state(false, true); game.hud.apply_reveals()
	s.tutorial.seen.erase("dusk")
	s.time.minute = 15 * 60.0
	game.game_event.connect(func(type, data): if type == "napgag": gags_seen.append(data.id))
	game.game_event.connect(func(type, data): if type == "paper": papers.append(data))
	await frames(10)
	var b := feature("benchSquare")
	var tree := a_tree()
	game.actions.deplete(tree)
	await at_bench()
	var ids: Array = game.panels.find_children("wake_*", "Button", true, false).map(func(x): return String(x.name))
	check("s1", "At 3 PM a bench offers a nap until dusk, sleep until tomorrow (which ends the day), or just sitting", game.panels.current == "sleep" and ids == ["wake_20", "wake_tomorrow"] and game.panels.find_child("just_sit", true, false) != null, "%s %s" % [game.panels.current, str(ids)])
	await shot("bench-panel")
	await click((game.panels.find_child("wake_20", true, false) as Control).get_global_rect().get_center())
	for n in 200:
		await frames(2)
		if game.mode == "explore": break
	await frames(10)
	check("s2", "Napping until dusk: 8:30 PM the same day", int(s.time.day) == 1 and absf(s.time.minute - 20.5 * 60.0) < 2.0, Clock.text(s.time))
	var on_bench: bool = not game.sitting.is_empty() and Vector2(game.player.pos.x - b.x, game.player.pos.z - b.z).length() < 1.0
	await get_up()
	check("s2b", "You wake up on the bench, and a step gets you up again", on_bench and game.sitting.is_empty(), "on the bench=%s, up=%s" % [on_bench, game.sitting.is_empty()])
	var t_dusk: float = s.time.total
	await frames(60)
	await shot("dusk")
	check("s3", "At dusk the clock waits for you, says so, and a tip card explains it", absf(s.time.total - t_dusk) < 0.01 and "waits" in game.hud.clock_label.text and "dusk" in s.tutorial.seen,
		"%.2f min passed; clock '%s'" % [s.time.total - t_dusk, game.hud.clock_label.text])
	check("s3b", "A tree cut before the nap hasn't grown back by dusk", not tree.is_empty() and not game.actions.ready(tree), tree.get("id", "no tree"))
	var e: QuestEngine = game.story.engine
	check("s3c", "Ornella's boars no longer wait for the morning: she asks at dusk", e.can_offer("squirrels") and game.story.marker_for("mabel") == "offer", game.story.marker_for("mabel"))
	var bed := feature("bed")
	game.player.teleport(bed.x - 0.95, bed.z + 0.5, PI / 2); game.cam.snap(); await frames(10)
	var label: String = game.target.label.call() if game.target != null and game.target.id == "bed" else ""
	await tap(KEY_E); await frames(8)
	check("s4", "The Sindaco's camp bed sends you to the public benches", "camp bed" in label and game.panels.current == "" and "benches" in last_toast() and int(s.time.day) == 1, "'%s' / '%s' / panel '%s'" % [label, last_toast(), game.panels.current])
	await frames(30)
	var woke := await bench_nap("auto", "wake_tomorrow", 7 * 60.0)
	var overnight_gag: String = game.nap_gags.gag
	await shot("morning-on-the-bench")
	await wait_explore()
	await frames(20)
	await shot("morning-paper")
	var paper: Dictionary = papers[-1] if not papers.is_empty() else {}
	check("s5", "A night on the bench ends the day: 7 AM on day 2, still on the bench, waking to a joke", woke and int(s.time.day) == 2 and absf(s.time.minute - 7 * 60.0) < 15.0 and overnight_gag != "",
		"%s, gag '%s'" % [Clock.text(s.time), overnight_gag])
	check("s6", "The morning paper reports on day 2", String(paper.get("title", "")).contains("Day 2") and game.hud.tip_card.visible and String(paper.get("headline", "")) != "", str(paper))
	check("s7", "The tree grew back overnight", game.actions.ready(tree), tree.get("id", ""))
	await talk("mabel")
	check("s8", "...and Ornella's request can be taken on in the morning too", e.status("squirrels") == "active", e.status("squirrels"))
	await get_up()
	await at_bench()
	var js := game.panels.find_child("just_sit", true, false) as Control
	if js: await click(js.get_global_rect().get_center()); await frames(10)
	check("s9", "...or just sit on the bench", not game.sitting.is_empty() and game.panels.current == "", "sitting=%s" % (not game.sitting.is_empty()))
	await get_up()
	var bench := feature("benchSquare")
	woke = await bench_nap("stared", "wake_12", 12 * 60.0)
	var w = game.nap_gags.watcher
	var near: float = Vector2(w.pos.x - bench.x, w.pos.z - bench.z).length() if w else 99.0
	await shot("nap-stared")
	var later := 0.0
	for k in 40:
		await frames(1)
		if w: later = maxf(later, Vector2(w.pos.x - bench.x, w.pos.z - bench.z).length())
	await wait_explore()
	check("n2", "A nap can end with a villager caught staring at you, who hurries off", woke and w != null and near < 2.0 and later > near + 3.0 and gags_seen.has("stared"),
		"%s: %.1f m from the bench, then %.1f m; line: %s" % [w.def.name if w else "nobody", near, later, game.nap_gags.line])
	woke = await bench_nap("newspaper", "wake_15", 15 * 60.0)
	var sheets: Array = game.nap_gags.paper.get_children() if game.nap_gags.paper else []
	var start: Array = sheets.map(func(sh): return sh.global_position)
	await shot("nap-newspaper")
	await frames(6)
	var flew := sheets.size() >= 3
	for i in sheets.size():
		if not is_instance_valid(sheets[i]) or sheets[i].global_position.distance_to(start[i]) < 0.5: flew = false
	await wait_explore(); await frames(30)
	check("n1", "...or under the local paper, and the wind takes it", woke and flew and not is_instance_valid(game.nap_gags.paper) and gags_seen.has("newspaper"),
		"%d sheets, flew=%s, line: %s" % [sheets.size(), flew, game.nap_gags.line])
	woke = await bench_nap("umbrella", "wake_20", 20.5 * 60.0)
	var um: Node3D = game.nap_gags.umbrella
	await frames(4)
	var dripping: bool = game.player_char.get_node_or_null("drips") != null
	await shot("nap-umbrella")
	check("n3", "...or soaked by a stranger's wet umbrella left open beside you", woke and um != null and Vector2(um.global_position.x - bench.x, um.global_position.z - bench.z).length() < 1.5 and dripping and gags_seen.has("umbrella"),
		"umbrella=%s, dripping=%s; line: %s" % [um != null, dripping, game.nap_gags.line])
	await wait_explore()
	Daylight.force(s, "rain", 12.0)
	woke = await bench_nap("auto", "wake_tomorrow", 7 * 60.0)
	await frames(4)
	var wet: bool = game.player_char.get_node_or_null("drips") != null and game.nap_gags.get_node_or_null("NapPuddle") != null
	await shot("nap-rain")
	check("n4", "...and a night out in the rain always gets you wet (the rules, not asked for)", woke and game.nap_gags.gag == "rain" and wet and gags_seen.has("rain") and int(s.time.day) == 3, "gag %s, wet=%s, %s" % [game.nap_gags.gag, wet, Clock.text(s.time)])
	await wait_explore()
	await get_up()
	check("n5", "...and the umbrella went with its owner by the next nap", not is_instance_valid(um), "")
	s.erase("forced_weather")
	s.flags["homePlot"] = true
	if not s.blueprints.has("bed"): s.blueprints.append("bed")
	s.inventory.wood = 3; s.inventory.fabric = 2; s.inventory.coins = 50; game.render_resources()
	var spot: Dictionary = game.walk.free_spot(18.0, -29.0, Rect2(), 6.0, WalkWorld.PLAYER_RADIUS, game.player.body)
	game.player.teleport(spot.x, spot.z); game.cam.snap(); await frames(10)
	await open_build("plot")
	await select_piece("bed")
	var poor := await place_anchored(18, -35, 0)
	var refused: bool = not s.placements.any(func(p): return p.id == "bed") and Drafts.of(s).any(func(p): return p.id == "bed")
	await shot("bed-too-dear")
	s.inventory.coins = 130; game.render_resources(); await frames(3)
	await place_anchored(18, -35, 0)
	var own: Array = s.placements.filter(func(p): return p.id == "bed")
	await shot("bed-bought")
	check("b1", "A bed costs 120,000 lire as well as its wood and fabric: with 50,000 it goes into the draft, with 130,000 a click on the draft builds it (10,000 left)",
		refused and "lire" in poor and own.size() == 1 and int(s.inventory.coins) == 10 and Drafts.of(s).is_empty(), "drafted: %s; then beds=%d, %d coins left, %d drafts" % [poor, own.size(), int(s.inventory.get("coins", 0)), Drafts.of(s).size()])
	await leave_build()
	if own.is_empty(): return
	var bb := BuildGrid.bounds(own[0])
	var bx: float = (bb.minX + bb.maxX) / 2.0
	var bz: float = (bb.minZ + bb.maxZ) / 2.0
	var stand: Dictionary = game.walk.free_spot(bx, bz + 1.4, Rect2(), 3.0, WalkWorld.PLAYER_RADIUS, game.player.body)
	game.player.teleport(stand.x, stand.z); game.cam.snap(); await frames(8)
	var day_before: int = int(s.time.day)
	var pressed := await face_and_press("pl:%d" % int(own[0].uid), bx, bz)
	await frames(6)
	var bed_btn := game.panels.find_child("wake_tomorrow", true, false) as Control
	var found := bed_btn != null
	if found: await click(bed_btn.get_global_rect().get_center())
	for n in 200:
		await frames(2)
		if game.mode == "explore" and int(s.time.day) > day_before: break
	await frames(20)
	check("b2", "Your own bed ends the day too, without a bench's jokes, and the paper still comes", pressed and found and int(s.time.day) == day_before + 1 and game.sitting.is_empty() and String(papers[-1].get("title", "")).contains("Day %d" % (day_before + 1)),
		"pressed=%s, button=%s, %s, sitting=%s" % [pressed, found, Clock.text(s.time), not game.sitting.is_empty()])
	await shot("own-bed-morning")
