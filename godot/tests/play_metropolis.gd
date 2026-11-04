extends "res://tests/full_base.gd"
## Toriano with real input: arrive at Toriano Centrale, take the tram to the Duomo and walk up its nave, through the
## Galleria, by tram to the Darsena and home to number 14 (up the courtyard stair, round the balcony into your flat,
## out onto the terrace), round the Darsena, over the old bridge into Franco's bar, by tram to the castle and a nap in
## the park, and back by tram to the train. Checks that the quays and the edge of the city stop you. Stage 3 adds the
## requests.
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

## Takes the tram with real input: walk to the stop, press E, click the destination, and wait to step off there.
func ride(from: String, to: String) -> bool:
	var a := feature(P + from); var b := feature(P + to)
	await walk_to(a.x + 1.0, a.z + (1.2 if a.z < 0 else -1.2), 0.8)
	var t0: float = game.state.time.minute + 1440.0 * float(game.state.time.day)
	if not await face_and_press(a.id, a.x, a.z): return false
	await frames(8)
	var btn := game.panels.find_child("ride_" + b.id, true, false) as Button
	if btn == null: note("no ride button for %s in panel '%s'" % [to, game.panels.current]); return false
	await click(btn.get_global_rect().get_center())
	for n in 300:
		await frames(2)
		if game.mode == "explore" and Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0: break
	var t1: float = game.state.time.minute + 1440.0 * float(game.state.time.day)
	var there := Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0
	check("ride_" + to, "the tram from %s to %s" % [a.name, b.name], there and t1 - t0 >= 2.0, "%.0f min later, %.1f m from the stop" % [t1 - t0, Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z))])
	await frames(10)
	return there

## True when the player stands inside a building's walls.
func inside(bid: String) -> bool:
	for b in Data.layout.buildings:
		if b.id == P + bid: return absf(game.player.pos.x - b.x) < b.w / 2.0 and absf(game.player.pos.z - b.z) < b.d / 2.0
	return false

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
	# Into town by tram, and into the Duomo
	await ride("stop_centrale", "stop_duomo")
	await shot("tram_duomo")
	await go("duomo:spot", "in through the Duomo's great door, up the nave")
	check("nave", "inside the nave, its roof and spires fading away overhead", inside("duomo"), "at %s" % game.player.pos)
	await shot("nave")
	var info := "%d draw calls, %d objects, %.0f fps (software renderer)" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Engine.get_frames_per_second()]
	await go("sq", "back out into the cathedral square")
	check("square_paved", "the cathedral square is paved in stone slabs", Ground.kind_at(game.player.pos.x, game.player.pos.z) == "slabs", Ground.kind_at(game.player.pos.x, game.player.pos.z))
	note("in the square: " + info)
	await shot("cathedral_square")
	await go("gal_mid", "into the Galleria, under its glass dome")
	await shot("galleria")
	# Home to number 14: the courtyard, the stair, the balcony, your flat, the terrace
	await go("sq", "back to the square")
	await ride("stop_duomo", "stop_darsena")
	await go("courtyard", "through the gate of number 14 into the courtyard")
	check("courtyard_setts", "the courtyard is laid with setts", Ground.kind_at(game.player.pos.x, game.player.pos.z) == "setts", Ground.kind_at(game.player.pos.x, game.player.pos.z))
	await shot("courtyard")
	await go("home:spot", "up the stair, round the balcony and in at your door")
	check("flat", "your flat is up on the first floor, off the balcony", inside("home") and absf(game.player.pos.y - 3.5) < 0.1, "at %s" % game.player.pos)
	await shot("flat")
	await go("terrace", "out onto the roof terrace over the back wing")
	check("terrace", "the terrace is up on the back wing's roof", absf(game.player.pos.y - 3.5) < 0.1 and inside("ten_s"), "at %s" % game.player.pos)
	await shot("terrace")
	await go("courtyard", "and back down the stair")
	check("down", "back down in the courtyard", game.player.pos.y < 0.5, "at %s" % game.player.pos)
	# The Darsena, the edge of the city, the old bridge and Franco's bar
	await go("darsena_n", "down to the Darsena's quay")
	var wet := await push_towards(-118, 105, 2.5)
	check("quay", "the quay stops you at the Darsena's edge", not Heightfield.is_water(wet.x, wet.z) and wet.z < 92.5, "stopped at %s" % wet)
	await shot("darsena")
	await go("canal_a_n", "along the quay to the old bridge")
	var edge := await push_towards(-200, 95, 5.0)
	check("edge", "the backdrop at the city's edge stops you", edge.x < -161.0 and edge.x > -163.6 and not Heightfield.is_water(edge.x, edge.z), "stopped at %s" % edge)
	await go("canal_a_n", "back to the bridge")
	await walk_direct(-157.0, 105.0, 0.6)
	check("bridge", "the old bridge's deck carries you over the flowing canal", Heightfield.is_water(game.player.pos.x, game.player.pos.z) and game.player.pos.y > 0.2, "at %s" % game.player.pos)
	await shot("bridge")
	await go("franco:spot", "over the bridge, along the quay and into Franco's bar")
	check("bar", "inside Franco's bar", inside("franco"), "at %s" % game.player.pos)
	await shot("bar")
	# The park by tram, a nap, and back to the train
	await go("bars_quay", "out of the bar")
	await go("s1_w", "back over the bridge to the tram")
	await ride("stop_darsena", "stop_castello")
	await go("pond_w", "into the park and round the duck pond")
	await shot("park")
	check("lawn", "the park is grass", Ground.kind_at(-140, -140) == "grass" and not Ground.paved(-104, -140), "%s, %s" % [Ground.kind_at(-140, -140), Ground.kind_at(-104, -140)])
	var bench: Dictionary = feature(P + "bench_park1")   # across the pond: walk round to it first
	await walk_to(bench.x - 1.4, bench.z, 0.6)
	var napped := await sleep_at(bench.id, 18)
	check("nap", "a nap on a park bench until evening", napped and game.state.time.minute >= 17.9 * 60.0 and game.state.time.minute < 19.5 * 60.0, "%.1f h" % (game.state.time.minute / 60.0))
	await shot("evening_park")
	await go("w_70", "back to the tram stop by the castle")
	await ride("stop_castello", "stop_centrale")
	game.state.flags["boatReady"] = true   # the train only runs once you've opened the line elsewhere
	await go("station", "across the station square")
	var train: Dictionary = feature(P + "train")
	var found := false
	for n in 6:
		if game.target != null and game.target.id == train.id: found = true; break
		await push_towards(train.x, train.z, 0.3)
	check("train", "the departure point says you can take the train", found and game.target.label.call() == "Take the train", game.target.label.call() if game.target else "nothing to do here")
	await shot("train")
