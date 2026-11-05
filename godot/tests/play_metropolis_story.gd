extends "res://tests/metropolis_base.gd"
## Toriano's main story with real key and mouse input: Augusto meets you at the station and you ride the tram home
## to number 14; you rent and furnish the balcony flat; drive the old crane with a waterwheel in the canal; build the
## footbridge over the Naviglio and walk across it; build a climb up the cathedral's side and walk up it onto the
## roof terrace; and light the Golden Angel with a windmill on the roof, then meet everyone in the square on
## Christmas Eve. Gathering is real (pruning, quarrying, skips, the flea market); materials for building beyond what
## a request asks you to gather are topped up by the harness, and says so. Ends by saving to slot 3, where
## play_metropolis_side.gd picks up.
## Run: TIMEOUT=4200 ./play.sh res://tests/play_metropolis_story.gd /tmp/out --island=metropolis --limit=4000

func at(npc: String) -> Vector3: return game.npcs[P + npc].pos

func play() -> void:
	lighten()
	game.state.tutorial = Tutorial.new_state(false, true)
	game.state.flags["hasTool"] = true   # by the time the train reaches the city you've long been the Geometra
	game.state.inventory["coins"] = 300   # savings from the villages
	game.state.time.minute = 10 * 60.0
	game.render_resources(); game.hud.render_harmony()
	note("harness: start at 10 AM with hasTool and 300,000 lire, as a player arriving from the villages")
	await frames(20)
	check("meter_hud", "the HUD shows La Sera di Toriano's column inches instead of approval", game.hud.harmony_title.text.contains("La Sera di Toriano") and game.hud.harmony_label.text == "0 in.", "%s %s" % [game.hud.harmony_title.text, game.hud.harmony_label.text])

	# ---- 1. Welcome to Toriano --------------------------------------------------------------------------------
	check("augusto_waits", "Augusto waits on the platform with a request", at("augusto").distance_to(game.player.pos) < 8.0 and game.story.marker_for(who("augusto")) == "offer", "%s, marker %s" % [at("augusto"), game.story.marker_for(who("augusto"))])
	await shot("augusto_station")
	await chat("augusto")
	check("welcome_on", "Augusto's welcome starts", status("welcome") == "active", status("welcome"))
	await ride("stop_centrale", "stop_darsena")
	check("welcome_tram", "the tram ride to the Darsena counts", step_done("welcome", "tram"), str(game.state.quests.get(P + "welcome", {}).get("progress", {})))
	await go("ten_gate", "to the gate of number 14")
	for n in 90:   # he walks; give him time
		if at("augusto").distance_to(Vector3(node("ten_gate").x, 0, node("ten_gate").y)) < 3.0: break
		await wait(1.0)
	await chat("augusto")
	check("welcome_gate", "Augusto meets you at the gate", step_done("welcome", "gate"))
	await chat("elvira"); await chat("simone"); await chat("sala")
	check("welcome_neighbours", "you meet Signora Elvira and Simone upstairs, and Ragioniere Sala", step_done("welcome", "elvira") and step_done("welcome", "simone") and step_done("welcome", "sala"),
		str(game.state.quests.get(P + "welcome", {}).get("done", {}).keys()))
	await chat("augusto")
	check("welcome_done", "Augusto gives you your keys: 5 column inches, and no approval for the Sindaco", done("welcome") and inches() == 5 and int(game.state.harmony) == 0 and game.state.flags.get(P + "settled", false), "%s, %d inches" % [status("welcome"), inches()])

	# ---- 2. The Balcony Flat ----------------------------------------------------------------------------------
	await chat("sala")
	check("flat_on", "Ragioniere Sala offers the flat", status("flat") == "active", status("flat"))
	await chat("sala")
	check("flat_rent", "you pay the rent in lire", step_done("flat", "rent") and game.state.flags.get(P + "rented", false), "coins %d" % inv("coins"))
	await go("home:spot", "up the stair, round the balcony and into your empty flat")
	await open_zone("flat")
	var placed := await put_all([["bed", -25, 108, 0, 3.5], ["table", -27, 108, 0, 3.5], ["chair", -28, 108, 1, 3.5], ["lamp", -27, 111, 0, 3.5]])
	await shot("flat_furnished")
	await leave_build()
	check("flat_furnished", "a bed, a table, a chair and a lamp go into the flat, up on the first floor", placed == 4 and step_done("flat", "furnish"), "%d placed" % placed)
	await chat("sala")
	var wardrobe: Array = game.interactables.filter(func(it): return it.id == P + "wardrobe")
	check("flat_done", "the flat is home: the wardrobe is yours and the roof terrace is your plot", done("flat") and game.state.flags.get(P + "home", false) and wardrobe.size() == 1 and wardrobe[0].available.call() \
		and game.zone_unlocked(Data.zone(P + "roof_terrace")), "%s, %d inches" % [status("flat"), inches()])
	check("notice", "10 column inches: a notice on page 18 and the streetlight plans", LocationMeter.reached(game.state, {"id": P + "notice"}) and game.state.blueprints.has("streetlight"), "%d inches" % inches())

	# ---- 3. Marble by Water -----------------------------------------------------------------------------------
	await chat("annoni")
	check("marble_on", "the Architetto asks you to get the marble moving", status("marble") == "active", status("marble"))
	await tram("stop_castello")
	await gather_until("chop", func(): return step_done("marble", "wood"), [], 12)
	check("marble_wood", "pruning the plane trees in the park gives wood", step_done("marble", "wood"), "wood %d" % inv("wood"))
	await shot("pruning")
	await tram("stop_darsena")
	await gather_until("bin", func(): return step_done("marble", "metal"), [P + "skip1", P + "skip2", P + "skip3", P + "skip4"], 6)
	check("marble_metal", "the builders' skips give metal and old bricks", step_done("marble", "metal") and inv("clay") >= 2, "metal %d, clay %d" % [inv("metal"), inv("clay")])
	await walk_to(-147.0, 98.0, 0.8)
	top_up({"wood": 6, "metal": 1}, "a waterwheel and a shaft")
	await open_zone("crane")
	placed = await put_all([["waterwheel", -145, 100, 0, 0.1], ["shaft", -145, 99, 0, 0.3]])
	await frames(30)
	await shot("crane_driven")
	await leave_build()
	check("crane", "a waterwheel in the flowing canal drives the old crane", placed == 2 and step_done("marble", "crane") and game.mech.fed.get(P + "crane", false), "%d placed, fed %s" % [placed, game.mech.fed])
	await chat("annoni"); await chat("annoni")
	check("marble_done", "the first barge unloads, and the request is done", done("marble"), "%s, %d inches" % [status("marble"), inches()])

	# ---- 4. The Footbridge ------------------------------------------------------------------------------------
	await chat("franco")
	check("footbridge_on", "Franco asks for a new footbridge", status("footbridge") == "active", status("footbridge"))
	await tram("stop_castello")
	if Data.layout.nodes.filter(func(n): return n.kind == "chop" and game.actions.ready(n)).size() < 4:
		await nap_at_least("bench_park1", 3.0)   # let the pruned trees grow back
	await gather_until("chop", func(): return step_done("footbridge", "wood"), [], 14)
	check("footbridge_wood", "more pruning for the deck and posts", step_done("footbridge", "wood"), "wood %d" % inv("wood"))
	await tram("stop_darsena")
	await walk_to(-115.0, 136.0, 0.8)
	top_up({"wood": 22}, "posts, planks and railings")
	await open_zone("footbridge")
	var bridge := [["bridgeDeck", -113, 135, 0, 0.3], ["bridgePost", -110, 135, 0, 0.0], ["bridgeDeck", -110, 135, 0, 0.0], ["bridgeDeck", -111, 135, 0, 0.0], ["bridgeDeck", -112, 135, 0, 0.0], ["bridgeDeck", -109, 135, 0, 0.0],
		["bridgePost", -107, 135, 0, 0.0], ["bridgeDeck", -107, 135, 0, 0.0], ["bridgeDeck", -108, 135, 0, 0.0], ["bridgeDeck", -106, 135, 0, 0.0],
		["bridgePost", -104, 135, 0, 0.0], ["bridgeDeck", -104, 135, 0, 0.0], ["bridgeDeck", -105, 135, 0, 0.0], ["bridgeDeck", -103, 135, 0, 0.0], ["bridgeDeck", -102, 135, 0, 0.3]]
	placed = await put_all(bridge)
	check("footbridge_built", "posts in the canal bed and planks across, quay to quay", step_done("footbridge", "bridge"), "%d of %d placed" % [placed, bridge.size()])
	placed = await put_all([["railing", -111, 135, 0, 0.15], ["railing", -111, 135, 2, 0.15], ["railing", -108, 135, 0, 0.15], ["railing", -108, 135, 2, 0.15], ["railing", -105, 135, 0, 0.15], ["railing", -105, 135, 2, 0.15]])
	await shot("footbridge")
	await leave_build()
	check("footbridge_rails", "railings along both sides", placed == 6 and step_done("footbridge", "rails"), "%d placed" % placed)
	await walk_direct(-113.5, 135.5, 0.5)
	await walk_direct(-101.0, 135.5, 0.5)
	check("footbridge_walk", "you walk across the Naviglio on your bridge", game.player.pos.x > -102.0 and absf(game.player.pos.z - 135.5) < 1.0, "at %s" % game.player.pos)
	await chat("franco")
	check("footbridge_done", "Franco's regulars can cross", done("footbridge"), "%s, %d inches" % [status("footbridge"), inches()])

	# ---- 5. Scaffolding for the Spire --------------------------------------------------------------------------
	await chat("annoni")
	check("scaffold_on", "the Architetto wants a climb up to the roof", status("scaffold") == "active", status("scaffold"))
	await tram("stop_castello")
	if Data.layout.nodes.filter(func(n): return n.kind == "chop" and game.actions.ready(n)).size() < 4:
		await nap_at_least("bench_park1", 3.0)
	await gather_until("chop", func(): return step_done("scaffold", "wood"), [], 12)
	await tram("stop_duomo")
	await gather_until("mine", func(): return step_done("scaffold", "stone"), [], 10)
	if not step_done("scaffold", "stone"):
		await nap_at_least("bench_sq2", 4.0)   # the offcuts come back
		await gather_until("mine", func(): return step_done("scaffold", "stone"), [], 10)
	check("scaffold_materials", "wood from the park and stone cut from the marble offcuts in the yard", step_done("scaffold", "wood") and step_done("scaffold", "stone"), "wood %d, stone %d" % [inv("wood"), inv("stone")])
	await walk_to(77.5, 10.5, 0.8)
	top_up({"stone": 30, "wood": 12}, "fifteen blocks and six stairs")
	await open_zone("scaffold")
	var climb: Array = []
	for n in 6:   # a stair a metre higher every tile, each on a stack of blocks one taller than the last
		var i := 75 - n
		for b in n: climb.append(["stoneBlock", i, 10, 0, 0.3 + b])
		climb.append(["stairs", i, 10, 3, 0.3 + n])
	placed = await put_all(climb)
	await shot("scaffold")
	await leave_build()
	check("scaffold_built", "a walkable climb from the works yard up to the roof terrace", step_done("scaffold", "climb"), "%d of %d placed" % [placed, climb.size()])
	await walk_direct(76.6, 10.5, 0.4)
	await walk_direct(67.5, 10.5, 0.5)
	check("scaffold_climbed", "you walk up your scaffolding onto the cathedral's roof terrace, 6.3 m up", game.player.pos.y > 6.1 and step_done("scaffold", "roof"), "at %s" % game.player.pos)
	await shot("on_the_roof")

	# ---- 6. The Golden Angel ----------------------------------------------------------------------------------
	# come down the way you went up, finish the scaffolding request and take on the last one
	await walk_direct(71.0, 10.5, 0.5); await walk_direct(77.5, 10.5, 0.5)
	await chat("annoni")
	check("scaffold_done", "the roof is reachable", done("scaffold"), "%s, %d inches" % [status("scaffold"), inches()])
	await chat("annoni")
	check("angel_on", "the Architetto asks you to light the Golden Angel", status("angel") == "active", status("angel"))
	await tram("stop_castello")
	if Data.layout.nodes.filter(func(n): return n.kind == "chop" and game.actions.ready(n)).size() < 3:
		await nap_at_least("bench_park1", 3.0)
	await gather_until("chop", func(): return step_done("angel", "wood"), [], 12)
	await tram("stop_darsena")
	await gather_until("bin", func(): return step_done("angel", "fabric"), [P + "flea"], 3)
	await gather_until("bin", func(): return step_done("angel", "metal"), [P + "skip1", P + "skip2", P + "skip3", P + "skip4"], 6)
	check("angel_materials", "wood, sailcloth from the flea market and metal from the skips", step_done("angel", "wood") and step_done("angel", "fabric") and step_done("angel", "metal"), "wood %d fabric %d metal %d" % [inv("wood"), inv("fabric"), inv("metal")])
	await tram("stop_duomo")
	await walk_to(77.5, 10.5, 0.8)
	await walk_direct(76.6, 10.5, 0.4); await walk_direct(66.0, 10.5, 0.5); await walk_direct(53.0, 10.5, 0.5)
	top_up({"wood": 6, "fabric": 2, "metal": 1}, "a windmill and a shaft")
	await open_zone("terrace")
	placed = await put_all([["windmill", 52, 9, 2, 6.3], ["shaft", 52, 8, 0, 6.3]])
	await frames(30)
	await shot("windmill_on_the_roof")
	await leave_build()
	check("angel_powered", "a windmill on the roof terrace drives the Golden Angel's floodlight", placed == 2 and step_done("angel", "light") and game.state.flags.get(P + "christmas_eve", false), "%d placed, fed %s" % [placed, game.mech.fed])
	await walk_direct(68.0, 10.5, 0.5); await walk_direct(77.5, 10.5, 0.5)
	if hour() < 18.0: await sleep_until("bench_sq1", 18)   # wait for dark on a bench in the square
	await frames(60)
	var crowd := 0
	for id in game.npcs:
		var a = game.npcs[id]
		if a.def.get("island", "") == "metropolis" and Vector2(a.pos.x + 10.0, a.pos.z - 4.0).length() < 40.0: crowd += 1
	check("eve_crowd", "Christmas Eve: the neighbourhood gathers in the cathedral square", crowd >= 8, "%d villagers in the square" % crowd)
	await chat("annoni")
	check("angel_lit_eve", "after dark the Golden Angel lights up over the square", step_done("angel", "eve") and game.state.flags.get(P + "angel_on", false), str(game.state.quests.get(P + "angel", {}).get("done", {}).keys()))
	await angel_shot()
	await chat("annoni")
	check("angel_done", "Buon Natale: the finale is done", done("angel") and game.state.flags.get(P + "angel_lit", false), "%s, %d inches" % [status("angel"), inches()])
	note("column inches after the main story: %d (milestones: %s)" % [inches(), game.state.unlocks_seen.filter(func(u): return String(u).begins_with(P))])
	check("saved", "the game saves to slot 3 for the side requests", await save_to("slot3"))

## A look up at the Golden Angel from the far side of the square, with the HUD out of the way.
func angel_shot() -> void:
	await walk_to(-44.0, 4.0, 1.0)
	var lim: Array = game.cam.limits.explore
	game.cam.limits.explore = [2.0, 120.0, -0.4, 1.5]
	game.cam.yaw = -PI / 2.0; game.cam.pitch = -0.18; game.cam.dist = 5.0
	game.ui_root.visible = false
	await frames(30)
	await shot("golden_angel")
	game.ui_root.visible = true
	game.cam.limits.explore = lim
