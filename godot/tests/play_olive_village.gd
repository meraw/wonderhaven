extends "full_base.gd"

const OV := preload("../scripts/locations/olive_village.gd")
const PLACES := ["hearthglow", "river_town", "rice_village", "metropolis", "port", "cliffs"]

func at(x: float, z: float, tol: float = 1.6) -> bool:
	return Vector2(game.player.pos.x - x, game.player.pos.z - z).length() < tol

func spot(id: String) -> Array:
	return Data.layout.nav_nodes[id]

func go(id: String) -> bool:
	var p := spot(id)
	await walk_to(p[0], p[1], 0.8)
	return at(p[0], p[1])

func play() -> void:
	await arrive_as_if_played(PLACES)
	var s: Dictionary = game.state
	var sp: Dictionary = Data.layout.spawn
	var finales := ["dock", "river_town_levee", "rice_village_train", "metropolis_angel"]
	var done := finales.all(func(q): return s.quests.get(q, {}).get("status", "") == "done")
	check("o1", "you arrive on the pebbles of the cove, with the earlier places' stories done", Data.island == "olive_village" and at(sp.x, sp.z, 2.5) and done, "at (%.1f, %.1f)" % [game.player.pos.x, game.player.pos.z])
	check("o2", "the clock doesn't hold at dusk here, and the sign reads 38", not WorkDay.holds(Data.island_def("olive_village").get("day", {})) and LocationMeter.reading(LocationMeter.def("olive_village"), LocationMeter.points(s, "olive_village")) == "38 inhabitants")
	await shot("cove")
	check("o3", "up the cart track's hairpins to the bridge", await go("bridgeE"))
	await shot("bridge_east")
	var peak := -INF
	var p := spot("bridgeW")
	var budget := 0
	key(KEY_SHIFT, true)
	while not at(p[0], p[1], 0.8) and budget < 400:
		steer(p[0], p[1])
		key(KEY_W, true)
		await frames(1)
		peak = maxf(peak, game.player.pos.y)
		budget += 1
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	check("o4", "over the hump-backed bridge into the village", at(p[0], p[1], 1.0) and peak > OV.BRIDGE_PEAK - 0.3, "highest %.2f m" % peak)
	await shot("bridge_west")
	check("o5", "up the alley past the wash-house to the piazza", await go("piazza"))
	await shot("piazza")
	check("o6", "up to the church and on to the castle on top", await go("churchDoor") and await go("castle"))
	await shot("castle")
	check("o7", "back over the bridge and along the lane to Bastian's farmhouse", await go("bastian"))
	check("o8", "up the rubble where the fallen terrace's wall came down", await go("fallenFoot") and await go("fallenTop"))
	check("o9", "up the terrace path to the broom terrace and Fuco's hut", await go("hives") and await go("fuco"))
	await shot("terraces")
	check("o10", "down the ramp to the shelf by the torrent, below the bridge", await go("millShelf") and absf(game.player.pos.y - OV.SHELF_H) < 0.1, "at %.2f m" % game.player.pos.y)
	check("o11", "down to the lower mule track", await go("mule1"))
	var top := spot("mule2")
	await walk_direct(top[0], top[1], 0.8, 12.0)
	check("o12", "the collapsed flight of the mule track can't be climbed", not at(top[0], top[1], 1.5), "stopped at (%.1f, %.1f)" % [game.player.pos.x, game.player.pos.z])
	check("o13", "back down to the beach", await go("beach"))
	await walk_direct(23.0, 75.0, 0.8, 8.0)
	check("o14", "the sea stops you at the water's edge", game.player.pos.z < OV.shore(game.player.pos.x) + 0.5 and not Heightfield.is_water(game.player.pos.x, game.player.pos.z), "at z %.1f" % game.player.pos.z)
	await shot("sea")
