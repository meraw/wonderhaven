extends "res://tests/full_base.gd"

func at(x: float, z: float, tol: float = 1.6) -> bool:
	return Vector2(game.player.pos.x - x, game.player.pos.z - z).length() < tol

func spot(id: String) -> Vector2:
	var a: Array = Data.layout.nav_nodes[id]
	return Vector2(a[0], a[1])

func go(id: String) -> bool:
	var p := spot(id)
	await walk_to(p.x, p.y, 1.0)
	return at(p.x, p.y, 1.6)

func y_near(v: float, tol: float = 0.4) -> bool: return absf(game.player.pos.y - v) < tol

func where() -> String: return "(%.1f, %.1f, %.1f)" % [game.player.pos.x, game.player.pos.y, game.player.pos.z]

func play() -> void:
	await arrive_as_if_played(["hearthglow", "river_town", "rice_village", "metropolis", "port"])
	var s: Dictionary = game.state
	s.tutorial = Tutorial.new_state(false, true)
	s.time.minute = 10 * 60.0
	game.hud.apply_reveals()
	await frames(10)
	var sp: Dictionary = Data.layout.spawn
	check("c1", "Arrived on Serenza's station platform", Data.island == "cliffs" and at(sp.x, sp.z, 2.5) and y_near(10.0), where())
	check("c2", "With Toriano's story played before it", s.quests.get("metropolis_angel", {}).get("status", "") == "done", "")
	await shot("arrival")
	var ok := await go("square")
	check("c3", "Down the station lane and the main street to the harbour square", ok and y_near(0.9), where())
	await shot("harbour-square")
	ok = await go("ferry")
	check("c4", "Out along the breakwater to the ferry landing", ok and y_near(1.1), where())
	ok = await go("beach")
	check("c5", "Onto the pebble beach", ok and game.player.pos.y > -0.3 and game.player.pos.y < 0.9, where())
	ok = await go("cellarSq")
	check("c6", "Under the railway arch and up the steps to the cellar square", ok and y_near(10.0), where())
	ok = await go("top0")
	check("c7", "Up the stair through the terraces to the pines at the top", ok and y_near(27.0), where())
	await shot("top-of-the-terraces")
	ok = await go("sanctuary")
	check("c8", "Along the top to the sanctuary", ok and y_near(29.5), where())
	await shot("sanctuary")
	ok = await go("muleGullyS")
	var north := spot("muleGullyN")
	await walk_direct(north.x, north.y, 0.8, 12.0)
	check("c9", "The gully stops you on the mule path until it's bridged", ok and game.player.pos.y < 19.0, where())
	ok = await go("rail5")
	var up := spot("rail6")
	await walk_direct(up.x, up.y, 0.8, 12.0)
	check("c10", "The slip stops you on the monorail's path", ok and game.player.pos.y < 21.0, where())
	ok = await go("platform")
	check("c11", "Back to the platform", ok and y_near(10.0), where())
