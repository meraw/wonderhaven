extends "res://tests/play_rice_village3.gd"

func pg() -> Pageant: return game.pageant
func beast(kind: String) -> Node3D: return game.village.find_child(P + kind, true, false)
func xz(v: Vector3) -> Vector2: return Vector2(v.x, v.z)
func near_mark(id: String, at: Vector2, tol: float = 0.35) -> bool:
	var m: Array = pg().last.placed.get(id, [])
	return not m.is_empty() and at.distance_to(Vector2(float(m[0]), float(m[1]))) < tol

func play() -> void:
	await arrive_as_if_played(["hearthglow", "river_town"])
	var s: Dictionary = game.state
	for qid in ["welcome", "flat", "stairs"]:
		s.quests[P + qid] = {"status": "done", "progress": {}, "done": {}}
	for item in {"wood": 12, "stone": 6, "crystal": 4, "clay": 2, P + "straw": 6}.keys():
		s.inventory[item] = {"wood": 12, "stone": 6, "crystal": 4, "clay": 2, P + "straw": 6}[item]
	game.render_resources()
	await frames(10)
	await talk_for(P + "remo", P + "nativity")
	check(1, "Don Remo asks for a stable for the living nativity", status("nativity") == "active", status("nativity"))
	await walk_to(-15.0, -3.7, 0.8)
	var placed := await build(P + "churchyard", [["pillar", -15, 0, 0], ["pillar", -14, 0, 0], ["roof", -15, 0, 0], ["lamp", -16, 1, 0], ["lamp", -13, 1, 0]])
	check(2, "the stable is built in the churchyard", progress("nativity", "stable") == 1, str(placed))
	await talk(P + "remo")
	check(3, "Don Remo has the straw for the manger", progress("nativity", "straw2") == 1, "straw %d" % inv(P + "straw"))
	await sleep_until(18)
	var donkey_was: Vector3 = beast("donkey").global_position
	var ox_was: Vector3 = beast("ox").global_position
	var remo = game.npcs[P + "remo"]
	for attempt in 6:
		await walk_to(remo.pos.x, remo.pos.z, 1.5)
		if await face_and_press("npc:" + P + "remo", remo.pos.x, remo.pos.z): break
	for n in 300:
		if pg().playing and pg().framed: break
		await frames(2)
	check(10, "talking to Don Remo in the evening starts the living nativity", pg().playing and not game.cam.cinema.is_empty(), "mode %s, %s, camera %s" % [game.mode, Clock.text(game.state.time), str(pg().last.get("camera", []))])
	var started := float(game.time)
	var seen := {}
	for n in 900:
		if not pg().playing: break
		await frames(2)
		var ui: DialogueUI = game.dialogue
		var line: int = pg().line_now
		if line < 0 or ui.typing or not ui.visible or seen.has(line): continue
		seen[line] = true
		await frames(45 if line != 3 else 2)
		match line:
			0:
				await shot("nativity-candles")
				check(11, "the candles along the church wall light up one by one", pg().lit() == Staging.candle_points(pg().spec).size() and pg().lit() > 0, "%d lit" % pg().lit())
				check(12, "the ox and the donkey are led into the stable", near_mark(P + "donkey", xz(beast("donkey").global_position)) and near_mark(P + "ox", xz(beast("ox").global_position)),
					"donkey %s ox %s" % [beast("donkey").global_position, beast("ox").global_position])
			1:
				await frames(20)
				await shot("nativity-holy-family")
				var silvia = game.npcs[P + "silvia"]; var tista = game.npcs[P + "battista"]; var matteo = game.npcs[P + "matteo"]
				check(13, "Silvia, Barba Tista and Matteo walk to their places", near_mark(P + "silvia", xz(silvia.pos)) and near_mark(P + "battista", xz(tista.pos)) and near_mark(P + "matteo", xz(matteo.pos)),
					"silvia %s tista %s matteo %s" % [silvia.pos, tista.pos, matteo.pos])
				check(14, "Silvia kneels by the manger in a blue veil, Barba Tista holds a staff, Matteo a crook", silvia.character.hold == "kneel" and silvia.character.head.get_node_or_null("pageant_veil") != null and tista.character.get_node_or_null("pageant_staff") != null and matteo.character.get_node_or_null("pageant_crook") != null,
					"silvia %s" % silvia.character.hold)
			2:
				await shot("nativity-song")
				check(15, "Nonna Pierina sings", game.npcs[P + "pierina"].character.hold == "sing", game.npcs[P + "pierina"].character.hold)
			3:
				await frames(6)
				await shot("nativity-bells")
				var life: Node = game.village.find_child(P + "life", true, false)
				check(16, "the bells ring out and everyone claps", life != null and float(life.pealed_at) >= started and int(pg().last.get("reacted", 0)) >= 4,
					"pealed at %s (scene from %.1f), %d clapped" % [str(life.pealed_at) if life else "no village life", started, int(pg().last.get("reacted", 0))])
		await tap(KEY_E)
	for n in 200:
		if not pg().playing: break
		await frames(2)
	check(17, "the scene ends and the village goes back to normal", not pg().playing and game.cam.cinema.is_empty() and game.npcs.values().all(func(a): return not a.held) and pg().candles.is_empty()
		and beast("donkey").global_position.distance_to(donkey_was) < 0.01 and beast("ox").global_position.distance_to(ox_was) < 0.01, "playing %s" % pg().playing)
	for n in 400:
		if game.mode != "dialogue": break
		var ui: DialogueUI = game.dialogue
		if ui.choices.is_empty(): await tap(KEY_E)
		else:
			for i in ui.choices.size():
				if ui.choices[i].kind == "bye":
					await tap(ui.key_for(i))
					break
		await frames(4)
	check(18, "the living nativity is done: Don Remo's thanks and the vin brulé", status("nativity") == "done" and inv(P + "vinbrule") >= 2, status("nativity"))
	check(19, "nobody is still wearing a costume", game.npcs[P + "silvia"].character.head.get_node_or_null("pageant_veil") == null and game.npcs[P + "battista"].character.get_node_or_null("pageant_staff") == null, "")
	await shot("after")
