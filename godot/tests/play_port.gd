extends "full_base.gd"

const Port := preload("../scripts/locations/port.gd")
const EARLIER := ["hearthglow", "river_town", "rice_village", "metropolis"]

func at(node: String, tol: float = 1.6) -> bool:
	var p: Array = Data.layout.nav_nodes[node]
	return Vector2(game.player.pos.x - p[0], game.player.pos.z - p[1]).length() < tol

func go(node: String) -> bool:
	var p: Array = Data.layout.nav_nodes[node]
	await walk_to(p[0], p[1], 1.0)
	note("at %s: %s" % [node, game.player.pos])
	return at(node)

func here() -> String: return Port.level(game.player.pos.x, game.player.pos.z)

func feet() -> float: return game.player.pos.y

func look(yaw: float, pitch: float, dist: float) -> void:
	game.cam.yaw = yaw; game.cam.pitch = pitch; game.cam.dist = dist
	game.cam.update(0.016, game.player.pos); game.cam.snap()
	await frames(4)

func await_rebuild(max_s: float = 60.0) -> bool:
	var old_id: int = game.get_instance_id()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_s * 1000.0:
		await frames(2)
		var cur = get_tree().current_scene
		if cur != null and cur.get_instance_id() != old_id and cur.get("started") == true:
			game = cur
			await frames(30)
			return true
	return false

func ride(from: String, to: String) -> bool:
	var a := feature(from); var b := feature(to)
	await walk_to(a.x + 1.0, a.z + (1.2 if a.z < 0 else -1.2), 0.8)
	if not await face_and_press(a.id, a.x, a.z): return false
	await frames(8)
	var btn := game.panels.find_child("ride_" + b.id, true, false) as Button
	if btn == null:
		note("no ride button for %s in panel '%s'" % [to, game.panels.current])
		return false
	await click(btn.get_global_rect().get_center())
	for n in 300:
		await frames(2)
		if game.mode == "explore" and Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0: break
	await frames(10)
	return Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0

func play() -> void:
	await arrive_as_if_played(EARLIER)
	game.state.time.minute = 10 * 60.0
	await frames(10)
	check(1, "the game is in Tonnarella", Data.island == "port", Data.island)
	var ar: Dictionary = Data.layout.arrive
	var off := Vector2(game.player.pos.x - ar.x, game.player.pos.z - ar.z).length()
	check(2, "off the train on the station forecourt, at the top", off < 1.0 and absf(feet() - Port.TOP_H) < 0.05, str(game.player.pos))
	check(3, "Toriano's finale is behind you and Tonnarella is on the travel map", game.state.flags.get("metropolis_angel_lit", false) and Travel.on_map(Data.island_def("port"), game.state.flags, "port"))
	await look(PI, 0.4, 12.0)
	await shot("arrival")

	check(4, "across the top to the belvedere", await go("port_belvedere") and here() == "top")
	await look(2.6, 0.45, 14.0)
	await shot("belvedere")
	check(5, "down the stair lane to the church square", await go("port_square") and here() == "middle" and absf(feet() - Port.MID_H) < 0.1, str(game.player.pos))
	await look(0.0, 0.5, 7.0)
	await shot("church-square")
	check(6, "along the main alley to Nonna Pina's door", await go("port_nonna_door"))
	check(7, "and back east to the door of your palazzo", await go("port_home_door"))
	check(8, "to the lookout at the end of the alley", await go("port_alley_e3"))
	await walk_direct(66.0, 0.0, 0.8, 6.0)
	check(9, "the parapet at the alley's end holds", here() == "middle" and game.player.pos.x < 56.0 and absf(feet() - Port.MID_H) < 0.1, str(game.player.pos))

	check(10, "down the lane by the fish market", await go("port_laneB3_foot") and feet() < 2.0, str(game.player.pos))
	check(11, "along the arcades to Rosetta's bakery", await go("port_bakery_door") and here() == "quay" and absf(feet() - Port.QUAY_H) < 0.1, str(game.player.pos))
	await look(0.3, 0.35, 12.0)
	await shot("arcades")
	check(12, "along the quay to the harbour office", await go("port_harbour_office_door"))
	check(13, "out along the breakwater to the gap", await go("port_breakwater_n") and here() == "breakwater", str(game.player.pos))
	var r: Array = Data.layout.nav_nodes["port_rock"]
	await walk_direct(r[0], r[1], 0.8, 8.0)
	check(14, "the gap stops you short of the lighthouse", here() == "breakwater" and game.player.pos.z < Port.GAP_Z.x and feet() > Heightfield.WALKABLE_MIN, str(game.player.pos))
	await look(PI, 0.4, 16.0)
	await shot("the-gap")

	check(15, "round the tip to the east rocks under the castle", await go("port_rocks_n") and here() == "rocks", str(game.player.pos))
	await look(-PI / 2.0, 0.35, 14.0)
	await shot("east-rocks")
	await walk_direct(50.0, game.player.pos.z, 0.8, 6.0)
	check(16, "the cliff under the castle can't be climbed", here() == "rocks" and feet() < 2.0, str(game.player.pos))
	check(17, "all the way back up to the castle gate", await go("port_castle_gate") and here() == "top" and absf(feet() - Port.TOP_H) < 0.1, str(game.player.pos))

	var train := feature("port_train")
	check(18, "back to the station", await go("port_station"))
	check(19, "the train is the way out", await face_and_press("port_train", train.x, train.z))
	await frames(10)
	var mv = game.panels.find_child("map_view", true, false)
	check(20, "and it opens the travel map", mv != null and (mv as Control).is_visible_in_tree(), String(game.panels.current))
	await shot("travel-map")
	game.panels.close()
	await frames(6)

	note("test-only: the lift's flag is set directly here; the request that powers it comes with the people and requests")
	check(21, "no lift stops before the lift runs", not Data.layout.features.any(func(f): return f.kind == "stop"))
	game.set_flag("port_lift_on")
	check(22, "the place is built again with the lift running", await await_rebuild())
	check(23, "three lift stops", Data.layout.features.filter(func(f): return f.kind == "stop").size() == 3)
	check(24, "ride the lift from the castle down to the harbour", await ride("port_lift_castle", "port_lift_harbour") and here() == "quay", str(game.player.pos))
	await look(0.0, 0.4, 10.0)
	await shot("lift-harbour")
	check(25, "and up to the church square", await ride("port_lift_harbour", "port_lift_church") and here() == "middle", str(game.player.pos))
