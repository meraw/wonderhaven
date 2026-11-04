extends "res://tests/full_base.gd"
## Boccapioppo (river_town) with real input. Stage 1 (ground and map): walk the map from the bus stop on the levee,
## down into the town and the piazza, north to the Roman bridge and over it to the east bank and the sawmill, back
## over the bridge, down onto the floodplain past the houseboat to the dance hall, and through the breach. Also
## checks that the canals keep you on the map and that the Alpine river can't be waded.
## Run: ./play.sh res://tests/play_river_town.gd /tmp/out --island=river_town

func at(x: float, z: float, tol: float = 1.6) -> bool:
	return Vector2(game.player.pos.x - x, game.player.pos.z - z).length() < tol

func play() -> void:
	var s: Dictionary = game.state
	s.tutorial = Tutorial.new_state(false, true)   # no guided day here yet: just walk
	s.time.minute = 10 * 60.0
	game.hud.apply_reveals(); await frames(10)
	check("r1", "A new game started with --island=river_town begins at the bus stop on the levee",
		Data.island == "river_town" and at(-45, 22) and game.player.pos.y > 2.5, "%s at %s" % [Data.island, game.player.pos])
	await shot("bus-stop")
	# along the levee road and down into the town
	await walk_to(-1, 15)
	check("r2", "Walked along the levee road and down its slope into the town", at(-1, 15) and game.player.pos.y < 1.0, str(game.player.pos))
	await walk_to(5, 4)
	check("r3", "Reached the piazza, the lowest part of town", at(5, 4) and game.player.pos.y < 0.45, str(game.player.pos))
	await shot("piazza")
	# north past the church to the Roman bridge, and over it
	await walk_to(21.5, -44)
	check("r4", "Reached the Roman bridge's west end", at(21.5, -44), str(game.player.pos))
	await walk_direct(RiverTown.alpine_center(RiverTown.ROMAN_Z), RiverTown.ROMAN_Z, 0.8)
	var top: float = game.player.pos.y
	await shot("roman-bridge")
	await walk_direct(36.5, -44, 0.8)
	check("r5", "Crossed the Roman bridge on foot, over the top of its hump", at(36.5, -44) and top > 1.6, "top %.2f, now %s" % [top, game.player.pos])
	await walk_to(45, 15.4)
	check("r6", "Walked down the east bank to the sawmill", at(45, 15.4), str(game.player.pos))
	await shot("east-bank")
	# the Alpine river can't be waded: walk straight at it from the east bank
	await walk_direct(RiverTown.alpine_center(13.0), 13.0, 0.5, 6.0)
	check("r7", "The Alpine river stops you: no wading across before the pontoon bridge exists",
		game.player.pos.x > RiverTown.alpine_center(13.0) + RiverTown.ALPINE_HALF - 1.0, str(game.player.pos))
	# back over the Roman bridge and down onto the floodplain
	await walk_to(-8, 28)
	check("r8", "Back over the bridge and down the levee onto the floodplain", at(-8, 28) and game.player.pos.y < 0.6, str(game.player.pos))
	await walk_to(-17.6, 29)
	check("r9", "Reached the stranded houseboat", at(-17.6, 29), str(game.player.pos))
	await shot("houseboat")
	await walk_to(16, 26.3)
	check("r10", "Reached the dance hall by the meeting of the rivers", at(16, 26.3), str(game.player.pos))
	await shot("dance-hall")
	# through the breach, from the floodplain back into the town
	await walk_direct(5, 26.5, 1.0)
	await walk_direct(5, 22, 0.8)
	var low: float = game.player.pos.y
	await shot("breach")
	await walk_direct(5, 16, 1.0)
	check("r11", "Walked through the breach in the levee, well below its crest", at(5, 16) and low < RiverTown.LEVEE_H - 1.5, "in the gap at %.2f" % low)
	# the canal at the west edge keeps you on the map
	await walk_to(-45, 22)
	await walk_direct(-62, 22, 0.5, 6.0)
	check("r12", "The canal at the west end of the levee keeps you on the map", game.player.pos.x > RiverTown.CANAL_W + RiverTown.CANAL_HALF - 0.5, str(game.player.pos))
	await shot("west-canal")

const RiverTown := preload("res://scripts/locations/river_town.gd")
