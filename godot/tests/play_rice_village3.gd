extends "res://tests/play_rice_village2.gd"
## Casalrana's requests with real input, part two: loads part one's save (slot 2) from the title screen, then Matteo's
## Train Log (by day, at night and at dawn), The Bell Tower Stairs (a climb you build and walk up, and the first peal),
## The Old Rice Mill, The Living Nativity (the stable, the straw, the evening) and the finale, The Train Stops Here
## (the inspector, the platform over its holes, the shelter, 250 signatures and the first stopping train). Stage 4 on the
## way: frost and thin ice at dawn, gone by noon; the night's tune; a V of cranes over the plain; and after the finale a
## regional waiting at the platform, which is now somewhere to leave from.
## It loads part one's save, so run play_rice_village2.gd first (with play_all.sh: play_rice_village2,play_rice_village3).
## Run: TIMEOUT=7100 ./play.sh res://tests/play_rice_village3.gd /tmp/out --island=rice_village --title --limit=7000
## Add --from=nativity to pick up from its save after the mill.

const TT := preload("res://scripts/locations/rice_village/timetable.gd")
const WATCH := Vector2(4.2, -41.2)   # where you stand to watch the trains at the crossing

func play() -> void:
	# --from=nativity picks up from the save this makes after the mill (slot 3), for the nativity and the finale
	if String(game.shot_cfg.get("from", "")) == "nativity":
		await load_slot("3")
		check(102, "resumed from the save after the mill", game.mode == "explore" and status("mill") == "done", "mode %s mill %s" % [game.mode, status("mill")])
	else:
		await load_slot("2")
		check(100, "part one's save loads from the title screen", game.mode == "explore" and Data.island == "rice_village" and status("museum") == "done", "mode %s island %s museum %s" % [game.mode, Data.island, status("museum")])
		if game.mode != "explore": return
		check(101, "the petition carried over", signatures() >= 140, "signatures %d" % signatures())
		await train_log()
		await stairs()
		check(126, "the frost has gone by the afternoon", float(game.state.time.minute) < 11 * 60 or float(game.state.time.minute) > 17 * 60 or frost() == 0.0, "%s frost %.2f" % [Clock.text(game.state.time), frost()])
		await mill()
		await cranes()
		check(139, "saved after the mill (slot 3)", await save_to("slot3"), "signatures %d" % signatures())
	await nativity()
	await finale()

func frost() -> float: return float((game.village.terrain.material_override as ShaderMaterial).get_shader_parameter("frost"))
func ice() -> float: return float((game.village.water.material_override as ShaderMaterial).get_shader_parameter("ice"))

## Waits for the cranes' next crossing (by the clock) and looks up at them.
func cranes() -> void:
	var W = load("res://scripts/locations/rice_village/wildlife.gd")
	var d := int(game.state.time.day); var m := int(game.state.time.minute)
	var at := -1
	for k in range(m, m + 2880):
		if W.crane_pass(d + int(k / 1440), float(k % 1440)) >= 0.0: at = k; break
	if at - m > 240:   # not within four hours: sleep to the morning and wait there
		await sleep_until(9)
	var seen := await wait_until(func(): return game.village.get_node("rice_village_wildlife").cranes.visible, 400.0)
	await wait_until(func(): return W.crane_pass(int(game.state.time.day), float(game.state.time.minute)) > 0.25, 60.0)
	var c: Node3D = game.village.get_node("rice_village_wildlife").cranes
	var p: Vector3 = game.player.pos
	game.cam.yaw = atan2(p.x - c.global_position.x, p.z - c.global_position.z); game.cam.pitch = 0.05; game.cam.dist = 7.0
	await frames(6)
	await shot("cranes")
	check(135, "a V of cranes passes high over the plain", seen, "%s, day %d" % [Clock.text(game.state.time), int(game.state.time.day)])

## Waits at the crossing until this kind of train has gone by (or max_s real seconds pass).
func watch_for(kind: String, max_s: float) -> bool:
	await walk_to(WATCH.x, WATCH.y, 0.6)
	return await wait_until(func(): return progress("trainlog", kind) >= 1, max_s)

## The next minute (from now, on today's or tomorrow's timetable) a train of this kind reaches the crossing.
func next_train(kind: String) -> float:
	var d := int(game.state.time.day); var m := float(game.state.time.minute)
	for day in [d, d + 1]:
		for tr in TT.trains_on(day):
			var at: float = float(tr.minute) + (day - d) * 1440.0
			if tr.kind == kind and at > m + 1.0: return at
	return INF

func sleep_until(hour: int) -> void:
	await to_bench()
	await sleep_at(P + "waitingBench", hour)

# ---- Matteo's Train Log -----------------------------------------------------------------------------------------
func train_log() -> void:
	await talk_for(P + "matteo", P + "trainlog")
	check(110, "Matteo asks for five trains for his log", status("trainlog") == "active", status("trainlog"))
	# the night express runs only at night: wait for it now if it's dark, or sleep till nine in the evening
	if not TT.is_night(float(game.state.time.minute)): await sleep_until(21)
	var ok := await watch_for("night_express", 2400.0)
	check(112, "the night express, after dark", ok, Clock.text(game.state.time))
	check(116, "the night has Casalrana's own night tune", game.audio != null and game.audio.want_song == P + "night", game.audio.want_song if game.audio else "no audio")
	await shot("night-express")
	# the yellow inspection train comes once, at dawn: wait up for it if it's due before six, or sleep till then
	var insp := next_train("inspection")
	if fposmod(insp, 1440.0) >= 360.0: await sleep_until(6)
	ok = await watch_for("inspection", 3600.0)
	check(113, "the yellow inspection train, at dawn", ok, "%s (it was due at %d)" % [Clock.text(game.state.time), int(fposmod(insp, 1440.0))])
	check(115, "hoarfrost on the ground and thin ice on the puddles at dawn", float(game.state.time.minute) > 8 * 60 or (frost() > 0.9 and ice() > 0.3), "%s frost %.2f ice %.2f" % [Clock.text(game.state.time), frost(), ice()])
	game.cam.yaw = 2.2; game.cam.pitch = 0.45; game.cam.dist = 14.0
	await frames(6)
	await shot("frost-at-dawn")
	await shot("inspection-train")
	# and the day's trains (at a couple of frames a second the game clock runs slow, so allow a while)
	for kind in ["regional", "intercity", "freight"]:
		ok = await watch_for(kind, 2400.0)
		check("111-" + kind, "watch a %s go by at the crossing" % kind, ok, Clock.text(game.state.time))
	await shot("train-watching")
	await talk(P + "matteo")
	check(114, "Matteo's Train Log is done", status("trainlog") == "done", status("trainlog"))

# ---- The Bell Tower Stairs --------------------------------------------------------------------------------------
func stairs() -> void:
	await talk_for(P + "remo", P + "stairs")
	check(120, "Don Remo asks for a way up the bell tower", status("stairs") == "active", status("stairs"))
	await gather_for("chop", "stairs", "wood", 8, "wood", 4)
	if inv("stone") < 2: await gather_to("mine", "stone", 2)
	await walk_to(-14.0, 12.4, 0.8)
	# far side first, so the camera (from the south) never has to aim past something already built
	var placed := await build(P + "tower", [["stoneBlock", -16, 8, 0], ["stairs", -16, 8, 0], ["stairs", -16, 9, 0]])
	note("tower: %s" % [placed])
	await frames(20)
	check(121, "build a climb inside the tower: a flight of stairs, and a second on a stone block", progress("stairs", "climb") == 1, str(placed))
	await walk_slow(-14.0, 10.4, 0.5); await walk_slow(-15.5, 10.4, 0.5); await walk_slow(-15.5, 7.7, 0.5)
	await walk_slow(-14.2, 7.5, 0.5)
	await shot("ringing-floor")
	check(122, "walk up it to the ringing floor", game.player.pos.y > 2.3, str(game.player.pos))
	check(123, "the tower's walls stay faded up there", game.roof_fade.get(P + "tower", 1.0) < 0.05, "%.2f" % game.roof_fade.get(P + "tower", 1.0))
	await face_and_press("rice_village_ropes", -14.0, 7.6)
	await frames(20)
	check(124, "pull the ropes: the first peal", progress("stairs", "peal") == 1 and game.state.flags.get("rice_village_bells", false), "")
	await walk_slow(-15.5, 8.6, 0.5); await walk_slow(-15.5, 10.5, 0.5); await walk_slow(-14.0, 10.5, 0.5); await walk_slow(-14.0, 12.6, 0.6)
	await talk(P + "remo")
	check(125, "The Bell Tower Stairs is done: 60 signatures", status("stairs") == "done", "signatures %d" % signatures())

# ---- The Old Rice Mill ------------------------------------------------------------------------------------------
func mill() -> void:
	await talk_for(P + "silvia", P + "mill")
	check(130, "Silvia wants the old mill turning again, now the canal is full", status("mill") == "active", status("mill"))
	await gather_for("chop", "mill", "wood", 6, "wood", 10, 24)
	await buy("battista", "metal", 1)
	check(131, "chop wood and buy metal", progress("mill", "wood") >= 6 and progress("mill", "metal") >= 2, "wood %d metal %d" % [progress("mill", "wood"), progress("mill", "metal")])
	await walk_to(-36.0, -9.0, 1.0)
	var row := [["waterwheel", -39, -13, 1]]
	for i in range(-38, -32): row.append(["shaft", i, -13, 1])
	var placed := await build(P + "mill", row)
	note("mill: %s" % [placed])
	await frames(30)
	check(132, "a waterwheel in the canal and shafts to the mill's drive", progress("mill", "drive") == 1 and game.mech.fed.get(P + "mill", false), str(placed))
	await shot("mill-turning")
	await talk(P + "silvia")
	check(133, "The Old Rice Mill is done: Casalrana rice in cloth bags", status("mill") == "done" and inv(P + "rice") >= 3 and game.state.flags.get("rice_village_millRunning", false), "rice %d" % inv(P + "rice"))

# ---- The Living Nativity ----------------------------------------------------------------------------------------
func nativity() -> void:
	await talk_for(P + "remo", P + "nativity")
	check(140, "Don Remo needs a new stable for the living nativity", status("nativity") == "active", status("nativity"))
	var straw: Array = Data.layout.nodes.filter(func(n): return n.get("gives", {}).has(P + "straw")).map(func(n): return n.id)
	await gather_until("flowers", func(): return progress("nativity", "straw") >= 6 and inv(P + "straw") >= 6, straw, 16)
	check(141, "gather loose straw on the stubble", progress("nativity", "straw") >= 6 and inv(P + "straw") >= 6, "straw %d" % inv(P + "straw"))
	await gather_for("chop", "nativity", "wood", 6, "wood", 5)
	if inv("stone") < 4: await gather_to("mine", "stone", 4)
	if inv("clay") < 1: await gather_to("clay", "clay", 1)
	if inv("crystal") < 2: await buy("ernesto", "crystal", 2 - inv("crystal"))
	await walk_to(-15.0, -3.7, 0.8)
	var placed := await build(P + "churchyard", [["pillar", -15, 0, 0], ["pillar", -14, 0, 0], ["roof", -15, 0, 0], ["lamp", -16, 1, 0], ["lamp", -13, 1, 0]])
	note("stable: %s" % [placed])
	check(142, "build the stable: posts, a roof and two lamps", progress("nativity", "stable") == 1, str(placed))
	await shot("stable")
	await talk(P + "remo")
	check(143, "hand Don Remo the straw for the manger", progress("nativity", "straw2") == 1 and inv(P + "straw") == 0, "straw %d" % inv(P + "straw"))
	await sleep_until(18)
	await talk(P + "remo")
	check(144, "come in the evening: the living nativity", status("nativity") == "done" and inv(P + "vinbrule") >= 2, "%s, remo at %s" % [Clock.text(game.state.time), game.npcs[P + "remo"].pos])

# ---- The Train Stops Here ---------------------------------------------------------------------------------------
func finale() -> void:
	await talk_for(P + "ernesto", P + "train")
	check(150, "Paletta brings news of a railway inspector", status("train") == "active", status("train"))
	await talk(P + "carlo")
	check(151, "Ingegner Pautasso sets his three conditions", progress("train", "meet") == 1, "carlo present %s" % game.npcs[P + "carlo"].present)
	await gather_to("chop", "wood", 21, 30)
	if inv("stone") < 4: await gather_to("mine", "stone", 4)
	if inv("clay") < 1: await gather_to("clay", "clay", 1)
	if inv("metal") < 1: await buy("battista", "metal", 1)
	if inv("crystal") < 2: await buy("ernesto", "crystal", 2 - inv("crystal"))
	await walk_to(8.5, -42.4, 1.0)
	var decks: Array = []
	for start in [10, 17, 25]:
		for i in range(start, start + 4): decks.append(["bridgeDeck", i, -43, 0])
	var placed := await build(P + "platform", decks)
	note("platform: %s" % [placed])
	await frames(20)
	check(152, "plank over the platform's three holes: one platform end to end", progress("train", "platform") == 1, str(placed))
	await walk_slow(9.0, -42.5, 0.6); await walk_slow(32.0, -42.5, 0.6, 60.0)
	check(153, "and walk it from the station end to the far end", game.player.pos.x > 31.0, str(game.player.pos))
	placed = await build(P + "platform", [["pillar", 29, -44, 0], ["pillar", 30, -44, 0], ["lamp", 31, -44, 0], ["roof", 29, -44, 0], ["bench", 29, -42, 0],
		["lamp", 31, -42, 0], ["enamelSign", 32, -42, 0]])
	note("shelter: %s" % [placed])
	await frames(20)
	check(154, "build the shelter: a roof, a bench, two lamps and an enamel sign", progress("train", "shelter") == 1, str(placed))
	await shot("platform-shelter")
	check(155, "the petition is full: 250 signatures", signatures() >= 250 and progress("train", "petition") == 1 and game.state.unlocks_seen.has("rice_village_full"), "signatures %d" % signatures())
	await talk(P + "carlo")
	check(156, "the inspector signs the order on his thermos", progress("train", "inspect") == 1, "")
	if float(game.state.time.minute) >= 11 * 60 or float(game.state.time.minute) < 6 * 60: await sleep_until(6)
	await talk(P + "ernesto")
	check(157, "the next morning the first regional train in years stops at Casalrana", status("train") == "done" and game.state.flags.get("rice_village_trainStops", false), "%s" % Clock.text(game.state.time))
	check(158, "Toriano opens on the travel map", Travel.on_map(Data.island_def("metropolis"), game.state.flags, "rice_village") if not Data.island_def("metropolis").is_empty() else true, "")
	await shot("finale")
	await regional_stops()

## After the finale: the next westbound regional stops at the platform, and the platform is somewhere to leave from.
func regional_stops() -> void:
	await walk_to(8.5, -42.4, 0.8)
	var stopped := await wait_until(func(): return TT.on_line(int(game.state.time.day), float(game.state.time.minute), true).any(func(x): return x.stopped), 300.0)
	var model := false
	for c in game.village.get_node("rice_village_trains").get_children():
		if c is Node3D and c.name.begins_with("train_regional") and absf(c.position.x - TT.STOP_X) < 0.2: model = true
	game.cam.yaw = 2.5; game.cam.pitch = 0.3; game.cam.dist = 12.0
	await frames(6)
	await shot("regional-stops")
	check(159, "a regional train stops at Casalrana's platform and waits", stopped and model, "%s, model at the platform %s" % [Clock.text(game.state.time), model])
	await wait_until(func(): return not TT.on_line(int(game.state.time.day), float(game.state.time.minute), true).any(func(x): return x.stopped), 30.0)
	await face_and_press(P + "platformStop", 8.5, -42.9); await frames(10)
	check(160, "the platform is now somewhere to leave from: the travel map opens", game.panels.current == "map", game.panels.current)
	await tap(KEY_ESCAPE); await frames(10)
