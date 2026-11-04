extends "res://tests/full_base.gd"
## Casalrana (rice_village) with real input. Stage 1 has no requests yet, so this walks the map: from the bus stop
## over the level crossing and back, along the station, out to the mill, the sluice, the farmstead and the spring
## pool, and checks that the railway and the canal keep you out. Later stages add the requests.
## Run: ./play.sh res://tests/play_rice_village.gd /tmp/out --island=rice_village

const RV := preload("res://scripts/locations/rice_village.gd")

func at(node: String, tol: float = 1.6) -> bool:
	var p: Array = Data.layout.nav_nodes[node]
	return Vector2(game.player.pos.x - p[0], game.player.pos.z - p[1]).length() < tol

func go(node: String) -> bool:
	var p: Array = Data.layout.nav_nodes[node]
	await walk_to(p[0], p[1], 1.0)
	note("at %s: %s" % [node, game.player.pos])
	return at(node)

func play() -> void:
	check(1, "the game starts in Casalrana", Data.island == "rice_village", Data.island)
	var sp: Dictionary = Data.layout.spawn
	check(2, "you arrive at the bus stop", Vector2(game.player.pos.x - sp.x, game.player.pos.z - sp.z).length() < 1.0, str(game.player.pos))
	await wait(1.0)
	await shot("arrival")
	check(3, "the sky is clear", game.weather_now.get("type", "") == "clear", str(game.weather_now.get("type", "")))

	check(4, "walk up the road to the level crossing", await go("crossingS"))
	check(5, "and over the line", await go("crossingN") and game.player.pos.z < RV.RAIL_Z - 2.0, str(game.player.pos))
	await shot("over-the-crossing")
	check(6, "and back", await go("crossingS"))
	check(7, "to the west end of the platform", await go("platformW"))
	# try to step onto the line beside the platform: the railway bed keeps you off
	await walk_direct(12.0, RV.RAIL_Z, 0.5, 6.0)
	check(8, "the line can't be walked on away from the crossing", game.player.pos.z > RV.RAIL_Z + 2.0, str(game.player.pos))

	check(9, "round to the station's front door", await go("stationDoor"))
	await shot("station")
	check(10, "to the old mill", await go("millDoor"))
	await shot("mill")
	check(11, "up the levee to the sluice", await go("sluice"))
	await walk_direct(RV.CANAL_X, game.player.pos.z, 0.5, 5.0)
	check(12, "the drained canal can't be walked into", game.player.pos.x > RV.CANAL_X + 1.6, str(game.player.pos))
	await shot("canal")

	check(13, "across to the farmstead's courtyard", await go("courtyard"))
	await shot("cascina")
	check(14, "down to the spring pool", await go("pool"))
	await shot("spring-pool")
	check(15, "back to the bus stop", await go("busStop"))
	check(16, "still clear skies at the end", game.weather_now.get("type", "") == "clear", str(game.weather_now.get("type", "")))
