extends "res://tests/autoplay_base.gd"
## The guided first day with real input: one step at a time, the HUD filling in, requests opening gradually.

const PlayStory := preload("res://tests/play_story.gd")
var helper

func step_id() -> String: return Tutorial.current(game.state.tutorial).get("id", "")

func wait_step(id: String, max_frames: int = 90) -> bool:
	for n in max_frames:
		if step_id() == id: return true
		await frames(1)
	return step_id() == id

func play() -> void:
	helper = PlayStory.new(); helper.game = game; add_child(helper)
	await frames(20)
	var hk: String = game.hotkeys.text
	check("t1", "A new game starts the guided day on its first step", game.hud.guide_card.visible and step_id() == "walk", game.hud.guide_text.get_parsed_text())
	check("t2", "Approval, resources, requests and later keys are hidden at first", not game.hud.harmony_box.visible and not game.hud_res.get_parent().visible and not hk.contains("Journal") and game.hud.tracker.get_child_count() == 0, hk)
	await shot("guide-walk")
	await hold(KEY_W, 1.6)
	check("t3", "Walking completes the first step", await wait_step("look"), step_id())
	var c := Vector2(640, 360)
	mouse_move(c); await frames(2); mouse_button(c, MOUSE_BUTTON_RIGHT, true)
	for i in 20: mouse_move(c + Vector2(i * 20, 0), Vector2(20, 0)); await frames(1)
	mouse_button(c + Vector2(400, 0), MOUSE_BUTTON_RIGHT, false)
	check("t4", "Looking around completes the second step", await wait_step("talk"), step_id())
	var od = game.npcs.percival
	check("t5", "The compass points at the Sindaco", Vector2(game.guide.target().x, game.guide.target().z).distance_to(Vector2(od.pos.x, od.pos.z)) < 0.5, str(game.guide.target()))
	await helper.approach(od.pos.x - 1.4, od.pos.z, od.pos.x, od.pos.z)
	await tap(KEY_E); await frames(30)
	check("t6", "The first conversation shows the talking tip", game.hud.tip_card.visible, "")
	await shot("tip-talk")
	await helper.talk_through()
	check("t7", "Taking the tool moves on to chopping and shows the request tracker and resources", await wait_step("chop") and game.hud.tracker.get_child_count() > 0 and game.hud_res.get_parent().visible, step_id())
	check("t8", "Other villagers have no requests yet during the guided day", game.story.marker_for("percival") == "", game.story.marker_for("percival"))
	for attempt in 4:
		var n: Dictionary = Data.node_def("tree%d" % attempt)
		await helper.approach(n.x, n.z + 1.4, n.x, n.z)
		await tap(KEY_E); await frames(5)
		if game.mode != "minigame": continue
		if attempt == 0: await frames(10); await shot("tip-chop")
		for k in 300:
			await frames(1)
			var mg = game.minigame.active.get("mg")
			if mg == null: break
			if not mg.done and mg.pause <= 0.0 and absf(mg.needle() - mg.center) < mg.width / 2.5: await tap(KEY_E)
		await frames(10)
		if game.state.quests.tool.progress.get("wood", 0) >= 3: break
	check("t9", "Three wood moves on to opening the bag", await wait_step("bag"), step_id())
	await tap(KEY_I); await frames(10); await tap(KEY_ESCAPE); await frames(5)
	check("t10", "Opening the bag moves on to the lost glasses", await wait_step("fragment"), step_id())
	var f: Dictionary = Data.node_def("frag0")
	game.player.teleport(f.x - 2, f.z, PI / 2); game.cam.yaw = -PI / 2; game.cam.snap(); await frames(2)
	await hold(KEY_W, 0.8)
	check("t11", "Picking up the glasses moves on to returning to the Sindaco", await wait_step("return"), step_id())
	od = game.npcs.percival
	await helper.approach(od.pos.x - 1.3, od.pos.z, od.pos.x, od.pos.z)
	await tap(KEY_E); await frames(5)
	await helper.talk_through(false)
	check("t12", "Turning in shows the approval bar and moves on to the journal", await wait_step("journal") and game.hud.harmony_box.visible, step_id())
	await tap(KEY_J); await frames(10); await tap(KEY_ESCAPE); await frames(5)
	check("t13", "Opening the journal moves on to meeting Fern", await wait_step("fern"), step_id())
	await shot("guide-fern")
	var skip: Control = game.hud.guide_card.find_child("guide_skip", true, false)
	await frames(5)
	await click(skip.get_global_rect().get_center())
	await frames(10)
	check("t14", "Skip ends the guided day: all keys shown, other requests open", not game.state.tutorial.on and game.hotkeys.text.contains("Map") and game.story.marker_for("percival") == "offer", game.hotkeys.text)
	await shot("after-skip")
