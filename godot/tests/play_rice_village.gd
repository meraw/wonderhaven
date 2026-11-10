extends "res://tests/full_base.gd"
## Casalrana (rice_village) with real input. No requests yet (stage 3 adds them), so this walks the map: from the
## bus stop over the level crossing and back, along the station, out to the mill, the sluice, the farmstead and the
## spring pool, and checks that the railway and the canal keep you out. It starts as if you'd come on the bus after
## Monteforchetta and Boccapioppo (arrive_as_if_played). Then (stage 2) it walks into every room
## through its door, and waits at the level crossing for a train: the barriers come down and keep you off the line,
## the train goes by, and you cross once they're up again.
## Run: ./play.sh res://tests/play_rice_village.gd /tmp/out --island=rice_village

const RV := preload("res://scripts/locations/rice_village.gd")
const TT := preload("res://scripts/locations/rice_village/timetable.gd")

## Walks in through a building's door (as play_interiors does) and says whether you ended up inside.
func walk_in(bid: String, frames_max: int = 400) -> bool:
	var b: Dictionary = {}
	for x in Data.layout.buildings:
		if x.id == bid: b = x
	var di := Interiors.door_info(b)
	var outside: Vector2 = di.c + di.out * 2.2
	var waypoints: Array = [di.c + di.out * 0.5, di.c - di.out * 1.6]
	var face := atan2(-di.out.x, -di.out.y)
	game.player.teleport(outside.x, outside.y, face); game.cam.yaw = face; game.cam.snap(); await frames(5)
	var room: AABB = Interiors.room(b, game.village.objects[bid].position.y)
	var n := 0
	for wp in waypoints:
		while n < frames_max:
			var p: Vector3 = game.player.pos
			var to: Vector2 = wp - Vector2(p.x, p.z)
			if to.length() < 0.35: break
			game.cam.yaw = atan2(-to.x, -to.y)
			key(KEY_W, true); await frames(1); n += 1
	key(KEY_W, false); await frames(30)
	var p2: Vector3 = game.player.pos
	return room.has_point(Vector3(p2.x, room.position.y + 1.0, p2.z))

## Sets the clock to just after a train has gone by, so the level crossing stays open for a good while.
func quiet_crossing() -> void:
	var day := int(game.state.time.day)
	for tr in TT.trains_on(day):
		var after: float = tr.minute + TT.length_of(tr.kind) / float(TT.KINDS[tr.kind].speed) + TT.CLEAR + 1.0
		if after > game.state.time.minute and after < 1400.0:
			game.state.time.minute = after; break
	await frames(5)

func at(node: String, tol: float = 1.6) -> bool:
	var p: Array = Data.layout.nav_nodes[node]
	return Vector2(game.player.pos.x - p[0], game.player.pos.z - p[1]).length() < tol

func go(node: String) -> bool:
	var p: Array = Data.layout.nav_nodes[node]
	await walk_to(p[0], p[1], 1.0)
	note("at %s: %s" % [node, game.player.pos])
	return at(node)

func play() -> void:
	await arrive_as_if_played(["hearthglow", "river_town"])   # off the bus from Boccapioppo, after Monteforchetta
	check(1, "the game starts in Casalrana", Data.island == "rice_village", Data.island)
	var sp: Dictionary = Data.layout.spawn
	check(2, "you arrive at the bus stop", Vector2(game.player.pos.x - sp.x, game.player.pos.z - sp.z).length() < 1.0, str(game.player.pos))
	await wait(1.0)
	note("frame rate at the bus stop: %d fps" % Engine.get_frames_per_second())
	await shot("arrival")
	check(3, "the sky is clear", game.weather_now.get("type", "") == "clear", str(game.weather_now.get("type", "")))

	await quiet_crossing()
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
	check(16, "still clear skies", game.weather_now.get("type", "") == "clear", str(game.weather_now.get("type", "")))

	# Stage 2: every room you can walk into, through its door
	var id := 20
	for bid in ["rice_village_station", "rice_village_casello", "rice_village_church", "rice_village_mill",
			"rice_village_farmhouse", "rice_village_office", "rice_village_shed"]:
		var inside := await walk_in(bid)
		await frames(20)
		check(id, "walk into %s through its door" % bid, inside and game.roof_fade.get(bid, 1.0) < 0.05, "pos %s roof %.2f" % [game.player.pos, game.roof_fade.get(bid, 1.0)])
		await shot("inside-" + bid.trim_prefix("rice_village_"))
		id += 1

	# Stage 2: wait at the crossing for the next train
	check(30, "back to the level crossing", await go("crossingS"))
	var day := int(game.state.time.day)
	var next: Dictionary = {}
	for tr in TT.trains_on(day):
		if tr.minute > game.state.time.minute + 8.0: next = tr; break
	if next.is_empty(): day += 1; next = TT.trains_on(day)[0]
	game.state.time.day = day; game.state.time.minute = next.minute - TT.LEAD - 3.0
	await frames(10)
	check(31, "the crossing is open before the train", not TT.crossing_closed(day, game.state.time.minute), "%s at %.1f" % [next.kind, next.minute])
	var t0 := Time.get_ticks_msec()
	while not TT.crossing_closed(day, game.state.time.minute) and Time.get_ticks_msec() - t0 < 30000: await frames(2)
	check(32, "the bells ring and the barriers come down", TT.crossing_closed(day, game.state.time.minute), "%.1f" % game.state.time.minute)
	# push towards the line for a few seconds while the barriers are down (not long enough for the train to pass)
	var pushed := 0
	key(KEY_SHIFT, true)
	while TT.crossing_closed(day, game.state.time.minute) and pushed < 30:
		steer(2.0, RV.RAIL_Z); key(KEY_W, true); await frames(1); pushed += 1
	key(KEY_W, false); key(KEY_SHIFT, false)
	check(33, "the barriers keep you off the line", game.player.pos.z > -44.0 and TT.crossing_closed(day, game.state.time.minute), "%s after %d frames of pushing" % [game.player.pos, pushed])
	while TT.at_crossing(day, game.state.time.minute).is_empty() and Time.get_ticks_msec() - t0 < 60000: await frames(1)
	check(34, "%s goes by" % TT.NAMES[next.kind], not TT.at_crossing(day, game.state.time.minute).is_empty() and game.village.get_node("rice_village_trains").get_child_count() > 0, "%.1f" % game.state.time.minute)
	note("frame rate as the train goes by: %d fps" % Engine.get_frames_per_second())
	await shot("train-" + next.kind)
	while TT.crossing_closed(day, game.state.time.minute) and Time.get_ticks_msec() - t0 < 90000: await frames(2)
	await frames(40)
	check(35, "the barriers go up again and you cross", await go("crossingN") and game.player.pos.z < RV.RAIL_Z - 2.0, str(game.player.pos))
	await go("crossingS")
	check(36, "still clear skies at the end", game.weather_now.get("type", "") == "clear", str(game.weather_now.get("type", "")))
	await platform_departure()

func train_prompt() -> bool:
	await frames(3)
	var tg = game.target
	return tg != null and String(tg.label.call()) == "Take the regional train"

func platform_departure() -> void:
	game.state.flags["boatReady"] = true
	game.state.flags[TT.STOP_FLAG] = true
	await go("platformW")
	check(40, "before the platform, no train to take", not await train_prompt(), str(game.player.pos))
	await walk_direct(7.5, -43.7, 0.5)
	game.player.yaw = PI; game.player.sync()
	var by_track := await train_prompt()
	game.player.yaw = 0.0; game.player.sync()
	var facing_away := await train_prompt()
	check(41, "after the finale, anywhere on the platform: take the regional train, facing the track or not", by_track and facing_away, "%s by the track %s, facing away %s" % [game.player.pos, by_track, facing_away])
	await walk_direct(9.6, -41.2, 0.5)
	game.player.yaw = PI / 2.0; game.player.sync()
	check(42, "and at the back of the platform, facing along it", await train_prompt(), str(game.player.pos))
	await tap(KEY_E); await frames(6)
	check(43, "E opens the travel map", game.panels.find_child("map_view", true, false) != null, game.mode)
	game.panels.close(); await frames(4)
	await go("stationDoor")
	check(44, "round at the station's front door, the platform is out of reach", not await train_prompt(), str(game.player.pos))
