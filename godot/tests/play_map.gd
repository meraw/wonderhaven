extends "res://tests/full_base.gd"
## The travel map with real mouse input: at first only Monteforchetta is on it; once the line to Toriano opens, Toriano
## turns up as a surprise and the view widens; clicking it and travelling takes you there. The map is opened as if
## from the bus stop (game.panels.map), a test-only shortcut past rebuilding the stop.
## Run: ./play.sh res://tests/play_map.gd /tmp/out

func play() -> void:
	game.state.tutorial = Tutorial.new_state(false, true)
	game.state.flags["boatReady"] = true
	await frames(10)
	game.panels.map(true); await frames(10)
	var mv: Control = game.panels.find_child("map_view", true, false)
	var ids: Array = mv.call("_shown").map(func(i): return i.id)
	check("m1", "a new game's map shows only Monteforchetta", ids == ["hearthglow"], str(ids))
	var narrow: Rect2 = mv.call("_frame")
	await shot("map_start")
	await tap(KEY_ESCAPE); await frames(6)
	game.state.flags["rice_village_trainStops"] = true   # what Casalrana's finale will set
	game.panels.map(true); await frames(10)
	mv = game.panels.find_child("map_view", true, false)
	ids = mv.call("_shown").map(func(i): return i.id)
	var wide: Rect2 = mv.call("_frame")
	check("m2", "once the line opens, Toriano turns up and the view widens", ids.has("metropolis") and wide.size.x > narrow.size.x, "%s, %d → %d wide" % [ids, narrow.size.x, wide.size.x])
	await shot("map_toriano")
	var city: Dictionary = Data.island_def("metropolis")
	await click(mv.get_global_rect().position + mv.call("to_screen", Vector2(city.x, city.y)))
	await frames(6)
	var go := game.panels.find_child("sail", true, false) as Button
	check("m3", "clicking Toriano tells you about it and offers the journey", go != null, "")
	await shot("map_picked")
	if go:
		await click(go.get_global_rect().get_center())
		var ok := await await_island("metropolis")
		var p: Vector3 = game.player.pos
		check("m4", "travelling takes you to Toriano Centrale", ok and Vector2(p.x, p.z).distance_to(Vector2(120, -132)) < 1.5, "at %s" % p)
		await shot("arrived")
