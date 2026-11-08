extends "res://tests/full_base.gd"

const SPOTS := WorldActions.SQUIRREL_SPOTS

func feed_step() -> Dictionary:
	return Data.quest("squirrels").objectives.filter(func(o): return o.id == "feed")[0]

func stage() -> int:
	game.story.engine.invalidate()
	return game.story.engine.current_stage("squirrels")

func fed(n: int) -> bool: return game.state.flags.get("squirrelFed%d" % n, false)

func feed(n: int) -> bool:
	var spot := Vector2(SPOTS[n][0], SPOTS[n][1])
	var stand := spot + (Vector2(-1.3, 0.6) if spot.x < -15.0 else Vector2(0.0, 1.4))
	await walk_to(stand.x, stand.y, 0.6)
	var sq: Dictionary = game.actions.squirrels[n]
	if not await face_and_press("squirrel%d" % n, sq.pos.x, sq.pos.y): return false
	await frames(12)
	return fed(n)

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge"]: s.quests[q] = {"status": "done", "progress": {}, "done": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen"]: s.flags[fl] = true
	s.tutorial = Tutorial.new_state(false, true); game.hud.apply_reveals()
	s.time.minute = 9 * 60.0
	s.inventory["acorn"] = 1
	await frames(10)
	check("b1", "Ornella asks about her boars and you take it on, one chestnut left over in your bag", await talk("mabel") and q("squirrels").get("status", "") == "active", str(q("squirrels")))
	check("b2", "With one chestnut you're still gathering: the request wants three", stage() == 0, "stage %d" % stage())
	check("b3", "A bakery boar takes your one chestnut before you've gathered three", await feed(1), "acorns %d" % inv("acorn"))
	await frames(30)
	var gone: float = game.actions.squirrels[1].home.distance_to(Vector2(SPOTS[1][0], SPOTS[1][1]))
	check("b4", "It trots off home to the woods, and the request is still on gathering", gone > 15.0 and stage() == 0, "%.1f m, stage %d" % [gone, stage()])
	await shot("early-boar")
	check("b5", "Shaking the chestnut tree by the bakery gives three more: on to the boars", await gather_node("oak0") and inv("acorn") >= 3 and stage() == 1, "acorns %d, stage %d" % [inv("acorn"), stage()])
	var both: bool = await feed(0)
	both = await feed(2) and both
	check("b6", "The two boars left at the bakery take theirs", both, "fed %s %s %s" % [fed(0), fed(1), fed(2)])
	game.story.engine.invalidate()
	var done: Dictionary = game.story.engine.objective("squirrels", feed_step())
	check("b7", "All three count, the early one too: on to Ornella's hazelnuts", done.done and stage() == 2, "%s, stage %d" % [str(done), stage()])
	await shot("boars-done")
	s = game.state
	s.quests.squirrels.progress = {"acorns": 3, "feed": 2}
	s.stats.erase("bakeryBoars")
	game.story.engine.invalidate()
	check("b8", "An old save: all three boars fed, only two counted, and no boar left at the bakery", not game.story.engine.objective("squirrels", feed_step()).done and stage() == 1, "stage %d" % stage())
	var saved: bool = await save_to("slot3")
	var loaded: bool = saved and game.load_from("slot3")
	await frames(20)
	check("b9", "Loading it counts the boars that are fed, and the request moves on to the hazelnuts", loaded and game.story.engine.objective("squirrels", feed_step()).done and stage() == 2, "saved %s loaded %s stage %d" % [saved, loaded, stage()])
