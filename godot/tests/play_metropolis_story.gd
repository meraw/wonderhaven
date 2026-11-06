extends "res://tests/metropolis_base.gd"
## Toriano's main story with real key and mouse input: Augusto meets you at the station and you ride the tram home
## to number 14; you rent and furnish the balcony flat; drive the old crane with a waterwheel in the canal; build the
## footbridge over the Naviglio and walk across it; build a climb up the cathedral's side and walk up it onto the
## roof terrace; and light the Golden Angel with a windmill on the roof, then meet everyone in the square on
## Christmas Eve. Gathering is real (pruning, quarrying, skips, the flea market); materials for building beyond what
## a request asks you to gather are topped up by the harness, and says so. Ends by saving to slot 3, where
## play_metropolis_side.gd picks up. Each request saves a checkpoint when it's done; --from=<request> starts there
## from the checkpoint before it (welcome, flat, marble, footbridge, scaffold, angel), to re-run the later ones.
## Run: TIMEOUT=10800 ./play.sh res://tests/play_metropolis_story.gd /tmp/out --island=metropolis --limit=10700

func at(npc: String) -> Vector3: return game.npcs[P + npc].pos

const STEPS := ["welcome", "flat", "marble", "footbridge", "scaffold", "angel"]
var approval_at_start := 0   # the Sindaco's approval you arrive with; Toriano's requests don't add to it

func checkpoint_slot(step: String) -> String: return "metropolis_after_" + step

func play() -> void:
	lighten()
	var from: String = String(game.shot_cfg.get("from", "welcome"))
	var first := STEPS.find(from)
	if first > 0:
		check("resume", "picks up from the checkpoint after %s" % STEPS[first - 1], game.load_from(checkpoint_slot(STEPS[first - 1])), checkpoint_slot(STEPS[first - 1]))
		await frames(20)
		note("resumed at %s, %.1f h, %d inches" % [from, hour(), inches()])
	else:
		await start_in_town()
	for i in range(maxi(first, 0), STEPS.size()):
		await call("step_" + STEPS[i])
		game.save_to(checkpoint_slot(STEPS[i]))
	note("column inches after the main story: %d (milestones: %s)" % [inches(), game.state.unlocks_seen.filter(func(u): return String(u).begins_with(P))])
	check("saved", "the game saves to slot 3 for the side requests", await save_to("slot3"))

## Arrives as a player would: Monteforchetta's, Boccapioppo's and Casalrana's main stories played (the travel order:
## Casalrana's train reveals Toriano; Progress.as_if_played), off the morning train at Toriano Centrale.
func start_in_town() -> void:
	await arrive_as_if_played(["hearthglow", "river_town", "rice_village"])
	lighten()
	game.state.time.minute = 10 * 60.0
	game.render_resources(); game.hud.render_harmony()
	note("arrived as if Monteforchetta, Boccapioppo and Casalrana were played: %s, %d approval, %d plans; off the 10 AM train" % [Money.lire(inv("coins")), int(game.state.harmony), game.state.blueprints.size()])
	await frames(20)
	check("meter_hud", "the HUD shows La Sera di Toriano's column inches instead of approval", game.hud.harmony_title.text.contains("La Sera di Toriano") and game.hud.harmony_label.text == "0 in.", "%s %s" % [game.hud.harmony_title.text, game.hud.harmony_label.text])

## Welcome to Toriano
func step_welcome() -> void:
	approval_at_start = int(game.state.harmony)
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
	check("welcome_done", "Augusto gives you your keys: 5 column inches, and no approval for the Sindaco", done("welcome") and inches() == 5 and int(game.state.harmony) == approval_at_start and game.state.flags.get(P + "settled", false), "%s, %d inches" % [status("welcome"), inches()])

## The Balcony Flat
func step_flat() -> void:
	await chat("sala")
	check("flat_on", "Ragioniere Sala offers the flat", status("flat") == "active", status("flat"))
	await chat("sala")
	check("flat_rent", "you pay the rent in lire", step_done("flat", "rent") and game.state.flags.get(P + "rented", false), "coins %d" % inv("coins"))
	await go("home:spot", "up the stair, round the balcony and into your empty flat")
	await open_zone("flat", -PI / 2.0)   # (from over the courtyard: the neighbours' roofs hide it from the street side)
	var placed := await put_all([["bed", -25, 108, 0, 3.5], ["table", -27, 108, 0, 3.5], ["chair", -28, 108, 1, 3.5], ["lamp", -27, 111, 0, 3.5]])
	await shot("flat_furnished")
	await leave_build()
	check("flat_furnished", "a bed, a table, a chair and a lamp go into the flat, up on the first floor", placed == 4 and step_done("flat", "furnish"), "%d placed" % placed)
	await chat("sala")
	var wardrobe: Array = game.interactables.filter(func(it): return it.id == P + "wardrobe")
	check("flat_done", "the flat is home: the wardrobe is yours and the roof terrace is your plot", done("flat") and game.state.flags.get(P + "home", false) and wardrobe.size() == 1 and wardrobe[0].available.call() \
		and game.zone_unlocked(Data.zone(P + "roof_terrace")), "%s, %d inches" % [status("flat"), inches()])
	check("notice", "10 column inches: a notice on page 18 and the streetlight plans", LocationMeter.reached(game.state, {"id": P + "notice"}) and game.state.blueprints.has("streetlight"), "%d inches" % inches())

## Marble by Water
func step_marble() -> void:
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
	var placed := await put_all([["waterwheel", -145, 100, 0, 0.1], ["shaft", -145, 99, 0, 0.3]])
	await frames(30)
	await shot("crane_driven")
	await leave_build()
	check("crane", "a waterwheel in the flowing canal drives the old crane", placed == 2 and step_done("marble", "crane") and game.mech.fed.get(P + "crane", false), "%d placed, fed %s" % [placed, game.mech.fed])
	await chat("annoni"); await chat("annoni")
	check("marble_done", "the first barge unloads, and the request is done", done("marble"), "%s, %d inches" % [status("marble"), inches()])
	check("photo_outfit", "25 column inches: your photo in the paper, and a long camel coat and a red scarf to go with it", game.state.clothes_owned.has(P + "camelcoat") and game.state.clothes_owned.has(P + "redscarf") and game.state.clothes_owned.has("longcoat"), "%d inches" % inches())

## The Footbridge
func step_footbridge() -> void:
	await chat("franco")
	check("footbridge_on", "Franco asks for a new footbridge", status("footbridge") == "active", status("footbridge"))
	await tram("stop_castello")
	if Data.layout.nodes.filter(func(n): return n.kind == "chop" and game.actions.ready(n)).size() < 4:
		await nap_at_least("bench_park1", 3.0)   # let the pruned trees grow back
	await gather_until("chop", func(): return step_done("footbridge", "wood"), [], 14)
	check("footbridge_wood", "more pruning for the deck and posts", step_done("footbridge", "wood"), "wood %d" % inv("wood"))
	await tram("stop_darsena")
	await walk_to(-115.0, 136.0, 0.8)
	top_up({"wood": 24}, "twelve planks, three posts and six railings")
	await open_zone("footbridge")
	var bridge := [["bridgeDeck", -113, 135, 0, 0.3], ["bridgePost", -110, 135, 0, 0.0], ["bridgeDeck", -110, 135, 0, 0.0], ["bridgeDeck", -111, 135, 0, 0.0], ["bridgeDeck", -112, 135, 0, 0.0], ["bridgeDeck", -109, 135, 0, 0.0],
		["bridgePost", -107, 135, 0, 0.0], ["bridgeDeck", -107, 135, 0, 0.0], ["bridgeDeck", -108, 135, 0, 0.0], ["bridgeDeck", -106, 135, 0, 0.0],
		["bridgePost", -104, 135, 0, 0.0], ["bridgeDeck", -104, 135, 0, 0.0], ["bridgeDeck", -105, 135, 0, 0.0], ["bridgeDeck", -103, 135, 0, 0.0], ["bridgeDeck", -102, 135, 0, 0.3]]
	var placed := await put_all(bridge)
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

## Scaffolding for the Spire
func step_scaffold() -> void:
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
	top_up({"stone": 60, "wood": 24}, "thirty blocks and twelve stairs for a stair two tiles wide")
	await open_zone("scaffold")
	var climb: Array = []
	for n in 6:   # a stair a metre higher every tile, each on a stack of blocks one taller than the last, two abreast
		var i := 75 - n
		for k in [10, 11]:
			for b in n: climb.append(["stoneBlock", i, k, 0, 0.3 + b])
			climb.append(["stairs", i, k, 3, 0.3 + n])
	climb.sort_custom(func(a, b): return a[4] < b[4])   # a layer at a time, so nothing already built stands taller than the cell being aimed at
	var placed := await put_all(climb)
	await shot("scaffold")
	await leave_build()
	check("scaffold_built", "a walkable climb from the works yard up to the roof terrace", step_done("scaffold", "climb"), "%d of %d placed" % [placed, climb.size()])
	await climb_scaffold(67.5)
	for n in 20:   # (the roof notices you on its next frame)
		if step_done("scaffold", "roof"): break
		await frames(1)
	check("scaffold_climbed", "you walk up your scaffolding onto the cathedral's roof terrace, 6.3 m up", game.player.pos.y > 6.1 and step_done("scaffold", "roof"), "at %s" % game.player.pos)
	await shot("on_the_roof")
	await descend_scaffold()
	await chat("annoni")
	check("scaffold_done", "the roof is reachable", done("scaffold"), "%s, %d inches" % [status("scaffold"), inches()])

## The Golden Angel
func step_angel() -> void:
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
	await climb_scaffold(66.0)
	await walk_direct(53.0, 11.0, 0.5)
	top_up({"wood": 6, "fabric": 2, "metal": 1}, "a windmill and a shaft")
	await open_zone("terrace")
	var placed := await put_all([["windmill", 52, 9, 2, 6.3], ["shaft", 52, 8, 0, 6.3]])
	await frames(30)
	await shot("windmill_on_the_roof")
	await leave_build()
	check("angel_powered", "a windmill on the roof terrace drives the Golden Angel's floodlight", placed == 2 and step_done("angel", "light") and game.state.flags.get(P + "christmas_eve", false), "%d placed, fed %s" % [placed, game.mech.fed])
	await walk_direct(67.0, 11.0, 0.5)
	await descend_scaffold()
	if hour() < 18.0: await sleep_until("bench_sq1", 18)   # wait for dark on a bench in the square
	await frames(30)
	var Glow = load("res://scripts/locations/metropolis/glow.gd")
	check("lamps_at_dusk", "dusk comes at five: by six the street lamps and Christmas lights are lit (before the 20:30 night)", float(Glow.level) > 0.5, "glow %.2f at %.1f h, night flag %s" % [float(Glow.level), hour(), game.state.flags.get("night", false)])
	var crowd := 0
	for n in 90:   # (wait in the square while they walk over from all over the city)
		await frames(10)
		crowd = 0
		for id in game.npcs:
			var a = game.npcs[id]
			if a.def.get("island", "") == "metropolis" and Vector2(a.pos.x + 10.0, a.pos.z - 4.0).length() < 40.0: crowd += 1
		if crowd >= 13: break
	check("eve_crowd", "Christmas Eve: the neighbourhood gathers in the cathedral square", crowd >= 8, "%d villagers in the square" % crowd)
	await chat("annoni")
	check("angel_lit_eve", "after dark the Golden Angel lights up over the square", step_done("angel", "eve") and game.state.flags.get(P + "angel_on", false), str(game.state.quests.get(P + "angel", {}).get("done", {}).keys()))
	var atmo = game.get_node("Atmosphere")
	for n in 60:   # the snow starts as she lights up, and settles on the square
		await frames(10)
		if float(atmo.snow_cover) > 0.5: break
	check("snow_on_christmas_eve", "and it starts to snow: flakes falling, and a white dusting settling on the square", Daylight.forced(game.state) == "snow" and float(game.weather_now.get("snow", 0.0)) > 0.5 and float(atmo.snow_cover) > 0.5,
		"%s, falling %.2f, dusting %.2f" % [Daylight.forced(game.state), float(game.weather_now.get("snow", 0.0)), float(atmo.snow_cover)])
	await angel_shot()
	await chat("annoni")
	check("angel_done", "Buon Natale: the finale is done", done("angel") and game.state.flags.get(P + "angel_lit", false), "%s, %d inches" % [status("angel"), inches()])

## Up the scaffolding (two tiles wide, so a hurrying player stays on it): from the works yard straight up it and on
## along the roof terrace to x.
func climb_scaffold(x: float) -> void:
	await walk_to(79.0, 11.0, 0.6)
	await walk_direct(78.5, 11.0, 0.4, 15.0)
	await walk_direct(x, 11.0, 0.4)
	if game.player.pos.y < 6.0: note("climb: ended at %s" % game.player.pos)

## And back down it into the works yard.
func descend_scaffold() -> void:
	await walk_direct(68.5, 11.0, 0.4, 20.0)
	await walk_direct(78.5, 11.0, 0.4)

## A look up at the Golden Angel from the far side of the square, with the HUD out of the way.
func angel_shot() -> void:
	# west of the tree, the crowd round it between you and the Duomo; there along the open north side of the square,
	# out of the way of anyone still walking to their spot along the middle
	for wp in [Vector2(0.0, -19.0), Vector2(-36.0, -19.0), Vector2(-40.0, -8.0)]: await walk_direct(wp.x, wp.y, 1.2)
	var lim: Array = game.cam.limits.explore
	game.cam.limits.explore = [2.0, 120.0, -0.4, 1.5]
	var to_angel := Vector2(52.0 - game.player.pos.x, 8.0 - game.player.pos.z).normalized()
	game.cam.yaw = atan2(-to_angel.x, -to_angel.y); game.cam.pitch = -0.22; game.cam.dist = 6.0   # just behind you, looking up at her
	game.ui_root.visible = false
	await frames(30)
	await shot("golden_angel")
	game.ui_root.visible = true
	game.cam.limits.explore = lim
