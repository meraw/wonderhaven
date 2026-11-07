extends "res://tests/full_base.gd"
## Sleeping until a chosen time, and requests that keep hours, with real input: nap on a bench in the square until the
## evening (you wake up on it), find Mabel's morning request isn't offered then, sleep in the castle's guest room
## until morning and find it is; a bench can also just be sat on. Then the jokes a bench nap can end with (the paper
## blowing away, a villager caught staring, a stranger's umbrella, the rain), and a bed's price in the build menu.
## Which joke a nap ends with is random in play; here each nap asks for one (napgag, test-only).

var gags_seen: Array = []

## Up off the bench, as a player would: a step forward.
func get_up() -> void:
	if game.sitting.is_empty(): return
	key(KEY_W, true); await frames(2); key(KEY_W, false); await frames(4)

## A nap on the square's bench until `hour`, ending with `gag` ("auto": as the rules decide). Returns once you're
## awake on the bench, with the screen faded back in and the joke (if any) under way.
func bench_nap(gag: String, hour: int) -> bool:
	game.shot_cfg["napgag"] = gag
	await get_up()
	var b := feature("benchSquare")
	game.player.teleport(b.x, b.z + 1.6, PI); game.cam.yaw = 0.0; game.cam.snap(); await frames(5)
	await face_and_press("benchSquare", b.x, b.z); await frames(6)
	var btn := game.panels.find_child("wake_%d" % hour, true, false) as Control
	if btn == null: note("no wake_%d in the bench panel" % hour); return false
	await click(btn.get_global_rect().get_center())
	for n in 300:
		await frames(1)
		if absf(game.state.time.minute - hour * 60.0) < 1.0 and not game.sitting.is_empty(): break
	await frames(13)   # the screen fades back in, a beat, and the joke
	return not game.sitting.is_empty()

func wait_explore() -> void:
	for n in 100:
		if game.mode == "explore": return
		await frames(2)

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}, "done": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen"]: s.flags[fl] = true
	s.tutorial = Tutorial.new_state(false, true); game.hud.apply_reveals()
	s.time.minute = 15 * 60.0
	game.game_event.connect(func(type, data): if type == "napgag": gags_seen.append(data.id))
	await frames(10)
	# A nap on the bench in the square, until the evening
	var b := feature("benchSquare")
	game.player.teleport(b.x, b.z + 1.6, PI); game.cam.yaw = 0.0; game.cam.snap(); await frames(5)
	var f := feature("benchSquare")
	await face_and_press("benchSquare", f.x, f.z); await frames(6)
	check("s1", "A bench offers a nap until a chosen time, or just sitting", game.panels.current == "sleep" and game.panels.find_child("wake_18", true, false) != null and game.panels.find_child("just_sit", true, false) != null, game.panels.current)
	await shot("bench-panel")
	await click((game.panels.find_child("wake_18", true, false) as Control).get_global_rect().get_center())
	for n in 200:
		await frames(2)
		if game.mode == "explore": break
	await frames(10)
	check("s2", "Napping until the evening: 6 PM the same day", int(s.time.day) == 1 and absf(s.time.minute - 18 * 60.0) < 2.0, Clock.text(s.time))
	var on_bench: bool = not game.sitting.is_empty() and Vector2(game.player.pos.x - b.x, game.player.pos.z - b.z).length() < 1.0
	await shot("evening")
	await get_up()
	check("s2b", "You wake up on the bench, and a step gets you up again", on_bench and game.sitting.is_empty(), "on the bench=%s, up=%s" % [on_bench, game.sitting.is_empty()])
	# Mabel's squirrel request is a morning one
	var e: QuestEngine = game.story.engine
	check("s3", "In the evening Mabel doesn't offer her morning request, but says when to come back", not e.can_offer("squirrels") and e.later_for("mabel").any(func(q): return q.id == "squirrels") and game.story.marker_for("mabel") != "offer", game.story.marker_for("mabel"))
	# Sleep in the castle's guest room (the camp bed in the hall) until morning
	var bed := feature("bed")
	game.player.teleport(bed.x - 0.95, bed.z + 0.5, PI / 2); game.cam.snap(); await frames(10)
	var ok := await sleep_at("bed", 9)
	check("s4", "Sleeping in the guest room until 9 AM: the next morning", ok and int(s.time.day) == 2 and absf(s.time.minute - 9 * 60.0) < 2.0, Clock.text(s.time))
	await frames(20)
	check("s5", "In the morning Mabel offers it", e.can_offer("squirrels") and game.story.marker_for("mabel") == "offer", game.story.marker_for("mabel"))
	await talk("mabel")
	check("s6", "...and you can take it on", e.status("squirrels") == "active", e.status("squirrels"))
	# Just sitting
	game.player.teleport(b.x, b.z + 1.6, PI); game.cam.snap(); await frames(5)
	await face_and_press("benchSquare", f.x, f.z); await frames(6)
	var js := game.panels.find_child("just_sit", true, false) as Control
	if js: await click(js.get_global_rect().get_center()); await frames(10)
	check("s7", "...or just sit on the bench", not game.sitting.is_empty() and game.panels.current == "", "sitting=%s" % (not game.sitting.is_empty()))
	await shot("sitting")
	# The paper you slept under blows away
	await get_up()
	var bench := feature("benchSquare")
	var woke := await bench_nap("newspaper", 21)
	var sheets: Array = game.nap_gags.paper.get_children() if game.nap_gags.paper else []
	var start: Array = sheets.map(func(sh): return sh.global_position)
	await shot("nap-newspaper")
	await frames(6)
	var flew := sheets.size() >= 3
	for i in sheets.size():
		if not is_instance_valid(sheets[i]) or sheets[i].global_position.distance_to(start[i]) < 0.5: flew = false
	await wait_explore(); await frames(30)
	check("n1", "A nap can end under the local paper, and the wind takes it", woke and flew and not is_instance_valid(game.nap_gags.paper) and gags_seen.has("newspaper"),
		"%d sheets, flew=%s, line: %s" % [sheets.size(), flew, game.nap_gags.line])
	# Someone was staring
	woke = await bench_nap("stared", 9)
	var w = game.nap_gags.watcher
	var near: float = Vector2(w.pos.x - bench.x, w.pos.z - bench.z).length() if w else 99.0
	await shot("nap-stared")
	var later := 0.0   # the farthest they got from the bench (their way home may pass by again later)
	for k in 40:
		await frames(1)
		if w: later = maxf(later, Vector2(w.pos.x - bench.x, w.pos.z - bench.z).length())
	await wait_explore()
	check("n2", "...with a villager caught staring at you, who hurries off", woke and w != null and near < 2.0 and later > near + 3.0 and gags_seen.has("stared"),
		"%s: %.1f m from the bench, then %.1f m; line: %s" % [w.def.name if w else "nobody", near, later, game.nap_gags.line])
	# A stranger's wet umbrella
	woke = await bench_nap("umbrella", 12)
	var um: Node3D = game.nap_gags.umbrella
	await frames(4)
	var dripping: bool = game.player_char.get_node_or_null("drips") != null
	await shot("nap-umbrella")
	check("n3", "...or soaked by a stranger's wet umbrella left open beside you", woke and um != null and Vector2(um.global_position.x - bench.x, um.global_position.z - bench.z).length() < 1.5 and dripping and gags_seen.has("umbrella"),
		"umbrella=%s, dripping=%s; line: %s" % [um != null, dripping, game.nap_gags.line])
	await wait_explore()
	# Rain while you slept: the rules decide, and they soak you
	Daylight.force(s, "rain", 12.0)   # test-only: bring rain for the nap
	woke = await bench_nap("auto", 18)
	await frames(4)
	var wet: bool = game.player_char.get_node_or_null("drips") != null and game.nap_gags.get_node_or_null("NapPuddle") != null
	await shot("nap-rain")
	check("n4", "...and sleeping out in the rain always gets you wet (the rules, not asked for)", woke and game.nap_gags.gag == "rain" and wet and gags_seen.has("rain"), "gag %s, wet=%s; line: %s" % [game.nap_gags.gag, wet, game.nap_gags.line])
	await wait_explore()
	await get_up()
	check("n5", "...and the umbrella went with its owner by the next nap", not is_instance_valid(um), "")
	s.erase("forced_weather")
	# Beds are dear: materials are not enough without 120,000 lire
	s.flags["homePlot"] = true
	if not s.blueprints.has("bed"): s.blueprints.append("bed")
	s.inventory.wood = 3; s.inventory.fabric = 2; s.inventory.coins = 50; game.render_resources()
	var spot: Dictionary = game.walk.free_spot(18.0, -29.0, Rect2(), 6.0, WalkWorld.PLAYER_RADIUS, game.player.body)
	game.player.teleport(spot.x, spot.z); game.cam.snap(); await frames(10)
	await open_build("plot")
	await select_piece("bed")
	var poor := await place_at(18, -34, 0.1, 0)
	var refused: bool = not s.placements.any(func(p): return p.id == "bed") and Drafts.of(s).any(func(p): return p.id == "bed")
	await shot("bed-too-dear")
	s.inventory.coins = 130; game.render_resources(); await frames(3)
	await place_at(18, -34, 0.1, 0)
	var bought: bool = s.placements.any(func(p): return p.id == "bed")
	await shot("bed-bought")
	check("b1", "A bed costs 120,000 lire as well as its wood and fabric: with 50,000 it goes into the draft, with 130,000 a click on the draft builds it (10,000 left)",
		refused and "lire" in poor and bought and int(s.inventory.coins) == 10 and Drafts.of(s).is_empty(), "drafted: %s; then bought=%s, %d coins left, %d drafts" % [poor, bought, int(s.inventory.get("coins", 0)), Drafts.of(s).size()])
	await leave_build()
