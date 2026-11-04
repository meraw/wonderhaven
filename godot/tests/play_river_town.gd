extends "res://tests/full_base.gd"
## Boccapioppo (river_town) with real input. Stages 1 and 2 (the map, the buildings and scenery): from the bus stop
## on the levee into Ermes's house at the levee's foot, down into the town (Pierina's house, the piazza, Rina's bar,
## Primo's workshop), north over the Roman bridge to the east bank and the sawmill (the Alpine river can't be waded),
## back onto the floodplain to Gildo and Mattia's shack and the stranded houseboat (sleep there until morning), up the
## ramp into the empty dance hall, through the breach, and to the canal that keeps you on the map.
## Run: TIMEOUT=2400 ./play.sh res://tests/play_river_town.gd /tmp/out --island=river_town --limit=2400

const RiverTown := preload("res://scripts/locations/river_town.gd")

func at(x: float, z: float, tol: float = 1.6) -> bool:
	return Vector2(game.player.pos.x - x, game.player.pos.z - z).length() < tol

func building(id: String) -> Dictionary:
	return Data.layout.buildings.filter(func(b): return b.id == id)[0]

## Is the player inside the room, with its roof faded away?
func inside(id: String) -> bool:
	var b := building(id)
	var o: Node3D = game.village.objects[id]
	var room := Interiors.room(b, o.position.y)
	return room.has_point(Vector3(game.player.pos.x, room.position.y + 1.0, game.player.pos.z))

## Walk to a room's spot along the nav graph (in through its door), let the roof fade, take a picture.
func enter(id: String, name: String) -> bool:
	var spot: Array = Data.layout.nav_nodes.get(id + ":spot", [])
	if spot.is_empty(): return false
	await walk_to(spot[0], spot[1], 0.7)
	await wait(1.0)
	await shot(name)
	return inside(id) and float(game.roof_fade.get(id, 1.0)) < 0.2

func play() -> void:
	var s: Dictionary = game.state
	s.tutorial = Tutorial.new_state(false, true)   # no guided day here yet: just walk
	s.time.minute = 10 * 60.0
	game.hud.apply_reveals(); await frames(10)
	check("r1", "A new game started with --island=river_town begins at the bus stop on the levee",
		Data.island == "river_town" and at(-45, 22) and game.player.pos.y > 2.5, "%s at %s" % [Data.island, game.player.pos])
	await shot("bus-stop")
	check("r2", "Ermes's keeper's house at the foot of the levee: in through its door, the roof fades",
		await enter("river_town_ermes_house", "ermes-house"), str(game.player.pos))
	await walk_to(-1, 15)
	check("r3", "Walked down from the levee into the town", at(-1, 15) and game.player.pos.y < 1.0, str(game.player.pos))
	check("r4", "Pierina's house: in through its door", await enter("river_town_pierina_house", "pierina-house"), str(game.player.pos))
	await walk_to(5, 4)
	check("r5", "Reached the piazza, the lowest part of town, still under a little water", at(5, 4) and game.player.pos.y < 0.45 and game.village.objects.has("river_town_pond"), str(game.player.pos))
	await shot("piazza")
	check("r6", "Rina's bar: in past the awning, behind her counter", await enter("river_town_bar", "bar"), str(game.player.pos))
	check("r7", "Primo's workshop: in through its door", await enter("river_town_workshop", "workshop"), str(game.player.pos))
	# north to the Roman bridge, and over it to the east bank
	await walk_to(21.5, -44)
	await walk_direct(RiverTown.alpine_center(RiverTown.ROMAN_Z), RiverTown.ROMAN_Z, 0.8)
	var top: float = game.player.pos.y
	await shot("roman-bridge")
	await walk_direct(36.5, -44, 0.8)
	check("r8", "Crossed the Roman bridge on foot, over the top of its hump", at(36.5, -44) and top > 1.6, "top %.2f, now %s" % [top, game.player.pos])
	await walk_to(45.9, 21)
	check("r9", "Down the east bank through the poplar plantation, under the sawmill's open shed", at(45.9, 21), str(game.player.pos))
	await shot("sawmill")
	await walk_to(38.8, 9.5)
	var bank := RiverTown.alpine_center(9.5) + RiverTown.ALPINE_HALF
	await walk_direct(bank + 0.8, 9.5, 0.6)
	var reached: bool = game.player.pos.x < bank + 1.6
	await walk_direct(RiverTown.alpine_center(9.5), 9.5, 0.5, 6.0)
	check("r10", "The Alpine river stops you at its bank: no wading across before the pontoon bridge exists",
		reached and game.player.pos.x > bank - 1.0, "bank at %.1f, stopped at %s" % [bank, game.player.pos])
	# back over the bridge and onto the floodplain
	check("r11", "Gildo and Mattia's fishing shack by the Po: in through its door", await enter("river_town_shack", "shack"), str(game.player.pos))
	await walk_to(-19.2, 29)
	await walk_direct(-22.4, 29.5, 0.5)
	await wait(1.0)
	check("r12", "The stranded houseboat: in through the stern door", inside("river_town_houseboat") and float(game.roof_fade.get("river_town_houseboat", 1.0)) < 0.2, str(game.player.pos))
	await shot("houseboat")
	s.time.minute = 22 * 60.0
	var day := int(s.time.day)
	var slept := await sleep_at("river_town_bed", 7)
	check("r13", "Slept in the houseboat until the next morning", slept and int(s.time.day) == day + 1 and absf(s.time.minute - 7 * 60.0) < 2.0, Clock.text(s.time))
	# up the ramp and into Wanda's dance hall, standing empty on its stilts
	check("r14", "Up the ramp and into the empty dance hall, on its raised floor", await enter("river_town_dance_hall", "dance-hall") and game.player.pos.y > RiverTown.DANCE_H - 0.1, str(game.player.pos))
	# through the breach, from the floodplain back into the town
	await walk_to(6.6, 31.5)
	await walk_direct(5, 26.5, 1.0)
	await walk_direct(5, 22, 0.8)
	var low: float = game.player.pos.y
	await shot("breach")
	await walk_direct(5, 16, 1.0)
	check("r15", "Walked through the breach in the levee, well below its crest", at(5, 16) and low < RiverTown.LEVEE_H - 1.5, "in the gap at %.2f" % low)
	# the canal at the west edge keeps you on the map
	await walk_to(-45, 22)
	await walk_direct(-62, 22, 0.5, 25.0)
	var edge: float = RiverTown.CANAL_W + RiverTown.CANAL_HALF
	check("r16", "The canal at the west end of the levee keeps you on the map: you reach its bank and stop",
		game.player.pos.x < edge + 2.0 and game.player.pos.x > edge - 0.5, "canal's edge at %.1f, stopped at %s" % [edge, game.player.pos])
	await shot("west-canal")
