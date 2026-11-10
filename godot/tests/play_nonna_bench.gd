extends "res://tests/play_rice_village2.gd"

func nonna(): return game.npcs[P + "pierina"]

func on_her_bench(p: Vector3) -> bool:
	for pl in game.state.placements:
		if String(pl.id) != "bench": continue
		if Seats.beside(Seats.spots(pl), p): return true
	return false

func seat_height() -> float:
	for pl in game.state.placements:
		if String(pl.id) == "bench": return float(pl.y) + Seats.SEAT_LIFT
	return INF

func sit_dialogue() -> bool:
	for n in 20:
		if game.mode == "dialogue": break
		await frames(2)
	if game.mode != "dialogue": return false
	for n in 300:
		await frames(4)
		if game.mode != "dialogue": return true
		var ui: DialogueUI = game.dialogue
		if ui.choices.is_empty():
			await tap(KEY_E)
			continue
		var idx := -1
		for i in ui.choices.size():
			if ui.choices[i].kind == "bye": idx = i
		await tap(game.dialogue.key_for(idx))
	return game.mode != "dialogue"

func front_view() -> void:
	var a: Vector3 = nonna().pos
	var b: Vector3 = game.player.pos
	var mid := (a + b) / 2.0
	var yaw: float = nonna().yaw
	game.cam.yaw = yaw + PI + 0.35; game.cam.cur.yaw = game.cam.yaw
	game.cam.pitch = 0.3; game.cam.dist = 4.2
	game.cam.update(0.016, mid); game.cam.snap()
	await frames(4)

func play() -> void:
	check(1, "the game starts in Casalrana", Data.island == "rice_village", Data.island)
	await arrive_as_if_played(["hearthglow", "river_town"])
	Progress._finish(game.state, Data.quest(P + "welcome"))
	await frames(10)
	await talk_for(P + "pierina", P + "bench")
	check(2, "Nonna asks for a bench by her paddy", status("bench") == "active", status("bench"))
	await gather_to("chop", "wood", 3)
	await walk_to(6.5, 32.6, 1.0)
	var bn := await build(P + "bench", [["bench", 9, 35, 0], ["flowerBed", 11, 35, 0]])
	check(3, "build her bench and a flower bed under the poplars", progress("bench", "build") == 1 and game.state.flags.get(P + "benchBuilt", false), str(bn))
	await to_bench()
	var slept := await sleep_at(P + "waitingBench", 18)
	check(4, "nap on the waiting-room bench until six", slept and float(game.state.time.minute) >= 18 * 60, Clock.text(game.state.time))
	var on := await wait_until(func(): return nonna().seated(), 120.0)
	check(5, "at dusk Nonna walks to her bench and sits down on it", on and on_her_bench(nonna().pos), "seated %s at %s" % [nonna().seated(), nonna().pos])
	check(6, "seated, not floating: on the seat, in the sitting pose", absf(nonna().pos.y - seat_height()) < 0.05 and nonna().character.hold == "sit", "y %.2f hold %s" % [nonna().pos.y, nonna().character.hold])
	var spot: Dictionary = game._spot_beside(nonna())
	check(7, "the other half of the bench is free", not spot.is_empty(), str(spot))
	if spot.is_empty():
		return
	var ap: Vector2 = spot.approach
	await walk_to(ap.x, ap.y, 0.4)
	await frames(4)
	check(8, "standing by the free half, E offers to sit with her", game.target != null and String(game.target.id) == "sitwith:" + P + "pierina", game.target.id if game.target else "no prompt")
	var hearts0 := int(game.state.relationships.get(P + "pierina", {}).get("hearts", 0))
	var ok := await face_and_press("sitwith:" + P + "pierina", spot.at.x, spot.at.z)
	await frames(6)
	var pp: Vector3 = game.player.pos
	var np: Vector3 = nonna().pos
	check(9, "you sit down beside her", ok and not game.sitting.is_empty() and game.player_char.hold == "sit", "sitting %s hold %s" % [not game.sitting.is_empty(), game.player_char.hold])
	check(10, "side by side on the same bench, a place each", on_her_bench(pp) and on_her_bench(np) and absf(Vector2(pp.x - np.x, pp.z - np.z).length() - 2.0 * Seats.HALF) < 0.1 and absf(pp.y - np.y) < 0.05, "you %s, Nonna %s" % [pp, np])
	check(11, "facing the same way, out over the paddy", absf(angle_difference(game.player.yaw, nonna().yaw)) < 0.05, "%.2f vs %.2f" % [game.player.yaw, nonna().yaw])
	var hearts1 := int(game.state.relationships.get(P + "pierina", {}).get("hearts", 0))
	check(12, "she makes room with a word, and it warms her to you", hearts1 == hearts0 + 1, "hearts %d -> %d" % [hearts0, hearts1])
	await front_view()
	await shot("nonna-and-you-on-her-bench")
	await frames(10)
	check(13, "from the seat, E talks to her", game.target != null and String(game.target.id) == "npc:" + P + "pierina", game.target.id if game.target else "no prompt")
	await tap(KEY_E)
	await frames(6)
	check(14, "the conversation starts with you both still sitting", game.mode == "dialogue" and not game.sitting.is_empty() and nonna().seated(), "mode %s" % game.mode)
	await shot("talking-on-the-bench")
	var talked := await sit_dialogue()
	check(15, "she sings you the mondina's song at dusk, from her bench", talked and progress("bench", "dusk") == 1, "dusk %d, status %s" % [progress("bench", "dusk"), status("bench")])
	check(16, "after talking you are still sitting beside her", not game.sitting.is_empty() and on_her_bench(game.player.pos) and nonna().seated(), str(game.player.pos))
	await sit_dialogue_if_needed()
	var seat_pos: Vector3 = game.player.pos
	await hold(KEY_S, 0.6)
	await frames(4)
	check(17, "moving gets you up off the bench", game.sitting.is_empty() and game.player.pos.distance_to(seat_pos) > 0.5 and game.player_char.hold != "sit", str(game.player.pos))
	check(18, "Nonna stays on her bench", nonna().seated() and on_her_bench(nonna().pos), str(nonna().pos))
	var sat_hearts := int(game.state.relationships.get(P + "pierina", {}).get("hearts", 0))
	var again: Dictionary = game._spot_beside(nonna())
	if not again.is_empty():
		var ap2: Vector2 = again.approach
		await walk_to(ap2.x, ap2.y, 0.4)
		await face_and_press("sitwith:" + P + "pierina", again.at.x, again.at.z)
		await frames(6)
	check(19, "sitting with her again the same day: no second heart", not game.sitting.is_empty() and int(game.state.relationships.get(P + "pierina", {}).get("hearts", 0)) == sat_hearts, "hearts %d" % int(game.state.relationships.get(P + "pierina", {}).get("hearts", 0)))
	await hold(KEY_S, 0.6)
	game.state.time.minute = 18.0 * 60.0 + 59.5
	var left := await wait_until(func(): return not nonna().seated() and not on_her_bench(nonna().pos) and nonna().pos.distance_to(np) > 3.0, 90.0)
	check(20, "at seven she gets up and walks home", left, "seated %s at %s" % [nonna().seated(), nonna().pos])
	check(21, "standing on the ground, not left at seat height", absf(nonna().pos.y - surface_at(nonna().pos.x, nonna().pos.z)) < 0.3, "y %.2f ground %.2f" % [nonna().pos.y, surface_at(nonna().pos.x, nonna().pos.z)])

func sit_dialogue_if_needed() -> void:
	if game.mode == "dialogue": await sit_dialogue()
