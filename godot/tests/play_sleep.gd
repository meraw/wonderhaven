extends "res://tests/full_base.gd"
## Sleeping until a chosen time, and requests that keep hours, with real input: nap on a bench in the square until the
## evening, find Mabel's morning request isn't offered then, sleep in the inn until morning and find it is; and a
## bench can also just be sat on.

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}, "done": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen"]: s.flags[fl] = true
	s.tutorial = Tutorial.new_state(false, true); game.hud.apply_reveals()
	s.time.minute = 15 * 60.0
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
	await shot("evening")
	# Mabel's squirrel request is a morning one
	var e: QuestEngine = game.story.engine
	check("s3", "In the evening Mabel doesn't offer her morning request, but says when to come back", not e.can_offer("squirrels") and e.later_for("mabel").any(func(q): return q.id == "squirrels") and game.story.marker_for("mabel") != "offer", game.story.marker_for("mabel"))
	# Sleep at the Lantern Inn until morning
	var bed := feature("bed")
	game.player.teleport(bed.x - 1.4, bed.z + 0.4, PI / 2); game.cam.snap(); await frames(10)
	var ok := await sleep_at("bed", 9)
	check("s4", "Sleeping in the inn until 9 AM: the next morning", ok and int(s.time.day) == 2 and absf(s.time.minute - 9 * 60.0) < 2.0, Clock.text(s.time))
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
