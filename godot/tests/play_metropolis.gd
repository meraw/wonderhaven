extends "res://tests/full_base.gd"
## Toriano with real input. Stage 1 (ground and map): arrive at Toriano Centrale and walk the street plan with real
## keys, through the Galleria to the cathedral square, into the courtyard of number 14, round the Darsena, over the
## old bridge to the bars, into the park; nap on a park bench; check that the quays and the edge of the city stop
## you; and come back to the train. Later stages add the trams and the requests.
## Run: TIMEOUT=1500 ./play.sh res://tests/play_metropolis.gd /tmp/out --island=metropolis --limit=1400

const P := "metropolis_"

func node(id: String) -> Vector2:
	var a: Array = Data.layout.nav_nodes[P + id]
	return Vector2(a[0], a[1])

## Walks along the nav graph to a named spot with real keys, then checks you got there.
func go(id: String, label: String) -> bool:
	var to := node(id)
	var t0 := Time.get_ticks_msec()
	await walk_to(to.x, to.y, 1.5)
	var d := Vector2(game.player.pos.x, game.player.pos.z).distance_to(to)
	check(id, label, d < 2.5, "%.1f m away after %.0f s" % [d, (Time.get_ticks_msec() - t0) / 1000.0])
	return d < 2.5

## Holds a key towards (x, z) for a while and reports where you ended up.
func push_towards(x: float, z: float, seconds: float) -> Vector3:
	steer(x, z)
	key(KEY_SHIFT, true); key(KEY_W, true)
	await wait(seconds)
	key(KEY_W, false); key(KEY_SHIFT, false)
	await frames(4)
	return game.player.pos

func play() -> void:
	game.state.tutorial = Tutorial.new_state(false, true)
	await frames(20)
	var p: Vector3 = game.player.pos
	check("arrive", "you arrive at Toriano Centrale, on the station square's paving", Data.island == "metropolis" and Ground.kind_at(p.x, p.z) == "slabs" and Vector2(p.x, p.z).distance_to(Vector2(120, -132)) < 1.0, "at %s on %s" % [p, Ground.kind_at(p.x, p.z)])
	check("size", "the city is three times as wide as a village", is_equal_approx(Data.map_size(), 372.0), str(Data.map_size()))
	await shot("station")
	var sign: Dictionary = feature(P + "station_sign")
	await walk_direct(sign.x + 1.2, sign.z - 0.6, 0.5)
	var read := await face_and_press(sign.id, sign.x, sign.z)
	await frames(6)
	check("sign", "the station sign can be read", read, "target: %s" % (game.target.id if game.target else "none"))
	await shot("station_sign")
	await go("opera", "along the tram street to the opera square")
	await shot("opera_square")
	await go("gal_mid", "into the Galleria, under where its glass dome will be")
	await shot("galleria")
	await go("sq", "out into the cathedral square")
	check("square_paved", "the cathedral square is paved in stone slabs", Ground.kind_at(game.player.pos.x, game.player.pos.z) == "slabs", Ground.kind_at(game.player.pos.x, game.player.pos.z))
	await shot("cathedral_square")
	await go("courtyard", "home to number 14, through the gate into the courtyard")
	check("courtyard_setts", "the courtyard is laid with setts", Ground.kind_at(game.player.pos.x, game.player.pos.z) == "setts", Ground.kind_at(game.player.pos.x, game.player.pos.z))
	await shot("courtyard")
	await go("darsena_n", "down to the Darsena's quay")
	# Walk straight at the water: the quay stops you.
	var wet := await push_towards(-118, 105, 2.5)
	check("quay", "the quay stops you at the Darsena's edge", not Heightfield.is_water(wet.x, wet.z) and wet.z < 92.5, "stopped at %s" % wet)
	await shot("darsena")
	# The edge of the city: from the west canal's quay, walk straight at the backdrop blocks 6 m away.
	await go("canal_a_n", "along the quay to the old bridge")
	var edge := await push_towards(-200, 95, 5.0)
	check("edge", "the backdrop at the city's edge stops you", edge.x < -161.0 and edge.x > -163.6 and not Heightfield.is_water(edge.x, edge.z), "stopped at %s" % edge)
	await shot("edge")
	await go("bars_quay", "over the old bridge to the bars on the far bank")
	await go("park_gate", "back up to the park gate")
	await go("pond_w", "round the duck pond")
	await shot("park")
	check("lawn", "the park is grass", Ground.kind_at(-140, -112) == "grass" and not Ground.paved(-104, -140), "")
	var napped := await sleep_at(P + "bench_park1", 18)
	check("nap", "a nap on a park bench until evening", napped and game.state.time.minute >= 17.9 * 60.0 and game.state.time.minute < 19.5 * 60.0, "%.1f h" % (game.state.time.minute / 60.0))
	game.state.flags["boatReady"] = true   # the train only runs once you've opened the line elsewhere
	await go("station", "back across the city to the station")
	var train: Dictionary = feature(P + "train")
	var found := false
	for n in 6:
		if game.target != null and game.target.id == train.id: found = true; break
		await push_towards(train.x, train.z, 0.3)
	check("train", "the departure point says you can take the train", found and game.target.label.call() == "Take the train", game.target.label.call() if game.target else "nothing to do here")
	await shot("train")
