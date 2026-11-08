extends "full_base.gd"

const Port := preload("../scripts/locations/port.gd")
const EARLIER := ["hearthglow", "river_town", "rice_village", "metropolis"]

var n := 0

func step(label: String, ok: bool, detail: String = "") -> void:
	n += 1
	check(n, label, ok, detail)

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

func building(id: String) -> Dictionary:
	return Data.layout.buildings.filter(func(b): return b.id == id)[0]

func inside(id: String) -> bool:
	var b := building(id)
	return Interiors.inside(b, Port.base_of(b), game.player.pos)

func enter(id: String, name: String) -> bool:
	var spot: Array = Data.layout.nav_nodes.get(id + ":spot", [])
	if spot.is_empty(): return false
	await walk_to(spot[0], spot[1], 0.7)
	await wait(1.0)
	await shot(name)
	return inside(id) and float(game.roof_fade.get(id, 1.0)) < 0.2

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

func ride(from: String, to: String, approach: Vector2 = Vector2.INF) -> bool:
	var a := feature(from); var b := feature(to)
	var spot := approach if approach != Vector2.INF else Vector2(a.x + 1.0, a.z + (1.2 if a.z < 0 else -1.2))
	await walk_to(spot.x, spot.y, 0.8)
	if not await face_and_press(a.id, a.x, a.z): return false
	await frames(8)
	var btn := game.panels.find_child("ride_" + b.id, true, false) as Button
	if btn == null:
		note("no ride button for %s in panel '%s'" % [to, game.panels.current])
		return false
	await click(btn.get_global_rect().get_center())
	for k in 300:
		await frames(2)
		if game.mode == "explore" and Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0: break
	await frames(10)
	return Vector2(game.player.pos.x, game.player.pos.z).distance_to(Vector2(b.x, b.z)) < 6.0

func play() -> void:
	await arrive_as_if_played(EARLIER)
	game.state.time.minute = 10 * 60.0
	await frames(10)
	step("the game is in Tonnarella", Data.island == "port", Data.island)
	var ar: Dictionary = Data.layout.arrive
	var off := Vector2(game.player.pos.x - ar.x, game.player.pos.z - ar.z).length()
	step("off the train on the station forecourt, at the top", off < 1.0 and absf(feet() - Port.TOP_H) < 0.05, str(game.player.pos))
	step("Toriano's finale is behind you and Tonnarella is on the travel map", game.state.flags.get("metropolis_angel_lit", false) and Travel.on_map(Data.island_def("port"), game.state.flags, "port"))
	await look(PI, 0.35, 12.0)
	await shot("arrival")

	step("across the top to the belvedere", await go("port_belvedere") and here() == "top")
	await look(2.6, 0.45, 14.0)
	await shot("belvedere")
	step("down the stair lane to the church square", await go("port_square") and here() == "middle" and absf(feet() - Port.MID_H) < 0.1, str(game.player.pos))
	await look(0.0, 0.4, 9.0)
	await shot("church-square")
	step("along the main alley to Nonna Pina's door", await go("port_nonna_door"))
	await look(0.2, 0.25, 7.0)
	await shot("nonna-balcony")
	step("and back east to the door of your palazzo", await go("port_home_door"))
	var flat := building("port_flat")
	step("up the 112 steps to the roof", await ride("port_stairs_street", "port_stairs_roof") and absf(feet() - float(flat.y)) < 0.1, str(game.player.pos))
	step("into your flat under the slates", await enter("port_flat", "your-flat"), str(game.player.pos))
	var door_in: Array = Data.layout.nav_nodes["port_flat:in"]
	await walk_direct(door_in[0], door_in[1], 0.5)
	await go("port_roof")
	await go("port_roof_e")
	await walk_direct(46.0, -5.0, 0.8, 5.0)
	step("the railing keeps you on the roof terrace", absf(feet() - float(flat.y)) < 0.1 and game.player.pos.x < 41.0, str(game.player.pos))
	await look(2.4, 0.35, 10.0)
	await shot("roof-terrace")
	step("and down the 112 steps again", await ride("port_stairs_roof", "port_stairs_street", Vector2(38.6, -9.9)) and absf(feet() - Port.MID_H) < 0.1, str(game.player.pos))
	step("to the lookout at the end of the alley", await go("port_alley_e3"))
	await walk_direct(66.0, 0.0, 0.8, 6.0)
	step("the parapet at the alley's end holds", here() == "middle" and game.player.pos.x < 56.0 and absf(feet() - Port.MID_H) < 0.1, str(game.player.pos))

	step("down the lane by the fish market", await go("port_laneB3_foot") and feet() < 2.0, str(game.player.pos))
	step("along the arcades to Rosetta's bakery", await go("port_bakery_door") and here() == "quay" and absf(feet() - Port.QUAY_H) < 0.1, str(game.player.pos))
	await look(0.35, 0.3, 12.0)
	await shot("arcades")
	step("into Rosetta's bakery", await enter("port_bakery", "bakery"), str(game.player.pos))
	step("out and into the savings bank", await enter("port_bank", "bank"), str(game.player.pos))
	step("along the quay into the harbour office", await enter("port_harbour_office", "harbour-office"), str(game.player.pos))
	step("out along the breakwater to the gap", await go("port_breakwater_n") and here() == "breakwater", str(game.player.pos))
	var r: Array = Data.layout.nav_nodes["port_rock"]
	await walk_direct(r[0], r[1], 0.8, 8.0)
	step("the gap stops you short of the lighthouse", here() == "breakwater" and game.player.pos.z < Port.GAP_Z.x and feet() > Heightfield.WALKABLE_MIN, str(game.player.pos))
	await look(PI, 0.4, 16.0)
	await shot("the-gap")

	note("test-only: the script steps over the gap here; the breakwater is mended in its request")
	var across: Array = Data.layout.nav_nodes["port_breakwater_s"]
	game.player.teleport(across[0], across[1])
	await frames(10)
	step("into the keeper's room at the foot of the lighthouse", await enter("port_keeper", "keepers-room"), str(game.player.pos))
	var lantern := building("port_lantern")
	step("round to the lighthouse door and up to the gallery", await ride("port_lantern_foot", "port_lantern_top", Vector2(41.9, 88.6)) and absf(feet() - float(lantern.y)) < 0.1, str(game.player.pos))
	step("into the lantern room", await enter("port_lantern", "lantern-room"), str(game.player.pos))
	var lantern_in: Array = Data.layout.nav_nodes["port_lantern:in"]
	await walk_direct(lantern_in[0], lantern_in[1], 0.5)
	await go("port_gallery")
	await walk_direct(44.2, 86.6, 0.5)
	await walk_direct(44.2, 76.0, 0.8, 4.0)
	step("the gallery's railing holds", absf(feet() - float(lantern.y)) < 0.1, str(game.player.pos))
	await look(2.8, 0.25, 9.0)
	await shot("gallery")
	step("down the lighthouse stair", await ride("port_lantern_top", "port_lantern_foot", Vector2(40.8, 86.6)) and feet() < 3.0, str(game.player.pos))
	var back: Array = Data.layout.nav_nodes["port_breakwater_n"]
	game.player.teleport(back[0], back[1])
	await frames(10)

	step("round the tip to the east rocks under the castle", await go("port_rocks_n") and here() == "rocks", str(game.player.pos))
	await look(-PI / 2.0, 0.3, 16.0)
	await shot("east-rocks")
	await walk_direct(50.0, game.player.pos.z, 0.8, 6.0)
	step("the cliff under the castle can't be climbed", here() == "rocks" and feet() < 2.0, str(game.player.pos))
	step("all the way back up to the castle gate", await go("port_castle_gate") and here() == "top" and absf(feet() - Port.TOP_H) < 0.1, str(game.player.pos))
	await look(-0.6, 0.3, 16.0)
	await shot("castle")

	var train := feature("port_train")
	step("back to the station", await go("port_station"))
	step("the train is the way out", await face_and_press("port_train", train.x, train.z))
	await frames(10)
	var mv = game.panels.find_child("map_view", true, false)
	step("and it opens the travel map", mv != null and (mv as Control).is_visible_in_tree(), String(game.panels.current))
	game.panels.close()
	await frames(6)

	note("test-only: the lift's flag is set directly here; the request that powers it comes with the people and requests")
	step("no lift stops before the lift runs", not Data.layout.features.any(func(f): return f.kind == "stop" and f.get("line", "") == "port_lift"))
	game.set_flag("port_lift_on")
	step("the place is built again with the lift running", await await_rebuild())
	step("three lift stops", Data.layout.features.filter(func(f): return f.kind == "stop" and f.get("line", "") == "port_lift").size() == 3)
	step("ride the lift from the castle down to the harbour", await ride("port_lift_castle", "port_lift_harbour") and here() == "quay", str(game.player.pos))
	step("and up to the church square", await ride("port_lift_harbour", "port_lift_church") and here() == "middle", str(game.player.pos))
	game.state.time.minute = 21 * 60.0
	await wait(2.0)
	await look(0.4, 0.3, 14.0)
	await shot("square-at-night")
