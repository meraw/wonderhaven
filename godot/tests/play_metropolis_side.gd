extends "res://tests/metropolis_base.gd"
## Toriano's thirteen side requests with real key and mouse input, picking up from the slot-3 save that
## play_metropolis_story.gd made (loaded from the title screen, like a player): Augusto's lost property, the
## residents' meeting and the bathroom in your flat, the tram shelter, Chiara's collection and shop window, Gino's
## score at night, the duck house, Gennaro's stall, Rocco's platform, the Roman finds, Simone's pergola, Elvira's
## tree and Franco's bicycles. Then the evening paper's last milestones: the radio and the front page in your flat.
## Gathering is real; materials for building beyond what a request asks you to gather are topped up, and noted.
## Run play_metropolis_story.gd first, then:
## TIMEOUT=4200 ./play.sh res://tests/play_metropolis_side.gd /tmp/out --island=metropolis --title --limit=4000

## Talks to a villager and picks a choice of one kind ("shop", "offer"...), then lets the conversation end.
func chat_choose(npc: String, kind: String) -> bool:
	var id := P + npc
	for attempt in 6:
		var a = game.npcs[id]
		await walk_to(a.pos.x, a.pos.z, 1.5)
		a = game.npcs[id]
		if await face_and_press("npc:" + id, a.pos.x, a.pos.z): break
	for n in 20:
		if game.mode == "dialogue": break
		await frames(2)
	var picked := false
	for n in 300:
		await frames(4)
		if game.mode != "dialogue": return picked
		var ui: DialogueUI = game.dialogue
		if not ui.choices.is_empty():
			var idx := -1
			if not picked:
				for i in ui.choices.size():
					if ui.choices[i].kind == kind: idx = i; break
			if idx >= 0: picked = true
			else:
				for i in ui.choices.size():
					if ui.choices[i].kind == "bye": idx = i
			await tap(KEY_1 + idx)
		else: await tap(KEY_E)
	return picked

## Buys a stock line at a villager's shop by clicking it, `times` times.
func buy(npc: String, line: int, times: int = 1) -> int:
	if not await chat_choose(npc, "shop"): note("no shop at %s" % npc); return 0
	await frames(10)
	var n := 0
	for t in times:
		var b := game.panels.find_child("buy_%d" % line, true, false) as Button
		if b == null or b.disabled: break
		await click(b.get_global_rect().get_center()); await frames(6); n += 1
	game.panels.close(); await frames(4)
	return n

func ready_count(kind: String, only: Array = []) -> int:
	return Data.layout.nodes.filter(func(n): return n.kind == kind and (only.is_empty() or only.has(n.id)) and game.actions.ready(n)).size()

const SKIPS := ["metropolis_skip1", "metropolis_skip2", "metropolis_skip3", "metropolis_skip4"]

func play() -> void:
	lighten()
	await frames(20)
	var title_load: Control = game.screens.find_child("btn_load", true, false)
	if title_load: await click(title_load.get_global_rect().get_center()); await frames(10)
	var l3: Control = game.screens.find_child("load_slot3", true, false)
	if l3: await click(l3.get_global_rect().get_center()); await frames(30)
	check("loaded", "the main story's save loads from the title screen, in Toriano", game.mode == "explore" and Data.island == "metropolis" and done("angel"), "mode %s, island %s, angel %s" % [game.mode, Data.island, status("angel")])
	if game.mode != "explore": return
	await frames(20)
	var start_inches := inches()
	check("interview", "45 column inches: the interview, and the bathroom plans", game.state.flags.get(P + "interview", false) and game.state.blueprints.has("toilet") and game.state.blueprints.has("bathtub"), "%d inches" % start_inches)
	check("column", "70 column inches: your column, and the roof terrace at number 14 grows along the back wing", BuildGrid.zone_contains(Data.zone(P + "roof_terrace"), -30, 123, LocationMeter.progress(game.state, "metropolis")) \
		and not BuildGrid.zone_contains(Data.zone(P + "roof_terrace"), -30, 123, 0), "%d inches" % start_inches)
	game.state.time.minute = 9 * 60.0   # (the save was made at night: sleep in, the harness skips to 9 AM next day)
	game.state.time.day = int(game.state.time.day) + 1
	note("harness: next morning, 9 AM")

	# ---- Ragioniere Sala: the residents' meeting, then the bathroom --------------------------------------------
	await go("courtyard", "home to the courtyard of number 14")
	await chat("sala")
	check("meeting_on", "Ragioniere Sala explains the residents' meeting", status("meeting") == "active", status("meeting"))
	await chat("elvira"); await chat("simone"); await chat("augusto")
	check("meeting_votes", "Elvira, Simone and Augusto vote for you", step_done("meeting", "elvira") and step_done("meeting", "simone") and step_done("meeting", "augusto"), str(game.state.quests.get(P + "meeting", {}).get("done", {}).keys()))
	if inv("coins") < 150: top_up({"coins": 150}, "the deposit")
	await chat("sala"); await chat("sala")
	check("meeting_done", "you pay the deposit and the flat is yours", done("meeting") and game.state.flags.get(P + "owner", false), "%s, coins %d" % [status("meeting"), inv("coins")])
	await chat("sala")
	check("bathroom_on", "after the interview, Sala approves a bathroom", status("bathroom") == "active", status("bathroom"))
	await ride("stop_darsena", "stop_duomo", true)
	await walk_to(48.0, 102.0, 1.0)   # the building site south of the cathedral
	if ready_count("bin", SKIPS) < 3: await sleep_until("bench_sq2", int(hour() + 5.0) % 24)
	await gather_until("bin", func(): return step_done("bathroom", "clay") and step_done("bathroom", "metal"), SKIPS, 8)
	if not step_done("bathroom", "metal"): await gather_until("mine", func(): return step_done("bathroom", "metal"), [], 6)
	check("bathroom_materials", "old bricks (clay) and metal from the skips", step_done("bathroom", "clay") and step_done("bathroom", "metal"), "clay %d, metal %d" % [inv("clay"), inv("metal")])
	await ride("stop_duomo", "stop_darsena", true)
	await go("home:spot", "home to the flat")
	top_up({"clay": 6, "metal": 4}, "the three pieces")
	await open_zone("flat")
	var placed := await put_all([["bathtub", -26, 110, 0, 3.5], ["toilet", -25, 111, 0, 3.5], ["washbasin", -25, 110, 0, 3.5]])
	await shot("bathroom")
	await leave_build()
	check("bathroom_fitted", "a toilet, a washbasin and a bathtub in your own flat", placed == 3 and step_done("bathroom", "fit"), "%d placed" % placed)
	await chat("sala")
	check("bathroom_done", "no more queueing down the balcony", done("bathroom"), status("bathroom"))

	# ---- Simone's pergola and Elvira's tree in the courtyard ---------------------------------------------------
	await chat("simone")
	await chat("elvira")
	check("courtyard_on", "Simone dares you to build his model; Elvira wants a tree", status("model") == "active" and status("tree") == "active", "%s, %s" % [status("model"), status("tree")])
	await walk_to(-37.0, 112.0, 0.8)
	top_up({"stone": 8, "wood": 12, "clay": 1, "flowers": 4, "metal": 2, "crystal": 2}, "pillars, a roof, benches, a tree, flower beds and lamps")
	await open_zone("courtyard")
	placed = await put_all([["pillar", -35, 113], ["pillar", -34, 113], ["pillar", -35, 114], ["pillar", -34, 114], ["roof", -35, 113, 0, 2.5], ["bench", -36, 116], ["bench", -36, 110]])
	check("model_built", "four pillars, a roof on them and two benches", step_done("model", "pergola"), "%d of 7 placed" % placed)
	placed = await put_all([["tree", -41, 116], ["flowerBed", -42, 116], ["flowerBed", -40, 116], ["lamp", -41, 114], ["lamp", -41, 118]])
	await shot("courtyard_built")
	await leave_build()
	check("tree_planted", "a young tree with flower beds and lamps round it", step_done("tree", "tree"), "%d of 5 placed" % placed)
	await chat("simone"); await chat("elvira")
	check("courtyard_done", "Simone's pergola stands, and Elvira has her tree", done("model") and done("tree"), "%s, %s" % [status("model"), status("tree")])

	# ---- Augusto's lost property ------------------------------------------------------------------------------
	await chat("augusto")
	check("lodge_on", "Augusto wants lost things for his lodge", status("lodge") == "active", status("lodge"))
	var lost: Array = Data.layout.nodes.filter(func(n): return n.kind == "fragment" and not n.has("gives"))
	for n in lost:
		if step_done("lodge", "lost"): break
		if not game.actions.ready(n): continue
		await walk_to(n.x, n.z, 0.6)
		await frames(10)
	check("lodge_found", "five lost things found in the streets", step_done("lodge", "lost"), "lost things %d" % inv("fragment"))
	await chat("augusto")
	check("lodge_done", "Augusto's cupboard is full again", done("lodge"), status("lodge"))

	# ---- Franco's bicycles ------------------------------------------------------------------------------------
	await chat("franco")
	check("canal_on", "Franco wants bicycles for his wall", status("canal") == "active", status("canal"))
	await gather_until("fish", func(): return step_done("canal", "bikes"), [], 24)
	check("canal_fished", "three old bicycles fished out of the canal (with boots, trolleys and carp)", step_done("canal", "bikes"), "bicycles %d, boots %d, trolleys %d, fish %d" % [inv(P + "bicycle"), inv(P + "boot"), inv(P + "trolley"), inv("fish")])
	await chat("franco")
	check("canal_done", "the bicycles go up on the wall", done("canal"), status("canal"))

	# ---- Chiara's collection and window -----------------------------------------------------------------------
	await ride("stop_darsena", "stop_opera", true)
	await chat("chiara")
	check("chiara_on", "Chiara's first collection", status("chiara") == "active", status("chiara"))
	var bought := await buy("chiara", 0, 2)
	check("chiara_shop", "her offcuts by the bundle, bought with lire", bought >= 1, "bought %d, fabric %d" % [bought, inv("fabric")])
	await ride("stop_opera", "stop_castello", true)
	await gather_until("flowers", func(): return step_done("chiara", "flowers"), [], 6)
	check("chiara_materials", "fabric, and winter flowers from the park beds", step_done("chiara", "fabric") and step_done("chiara", "flowers"), "fabric %d, flowers %d" % [inv("fabric"), inv("flowers")])
	await ride("stop_castello", "stop_opera", true)
	await chat("chiara")
	check("chiara_paid", "you hand Chiara the fabric and flowers", step_done("chiara", "hand"), str(game.state.quests.get(P + "chiara", {}).get("done", {}).keys()))
	await walk_to(-8.0, -80.5, 0.8)
	top_up({"wood": 8, "stone": 1, "fabric": 4, "flowers": 1, "crystal": 2}, "a counter, lamps, a rug, a wall and a painting")
	await open_zone("window")
	await tap(KEY_T)   # a splash of colour: the counter gets a new paint
	placed = await put_all([["counter", -9, -79], ["woodWall", -6, -78, 1], ["painting", -6, -78, 1, 1.2], ["rug", -9, -77, 0, 0.3], ["lamp", -7, -79], ["lamp", -6, -76]])
	await shot("chiara_window")
	await leave_build()
	check("chiara_window", "a counter, two lamps, a rug, a painting on a wall and a splash of colour", step_done("chiara", "window"), "%d of 6 placed" % placed)
	await chat("chiara")
	check("chiara_done", "shoppers stop at the window", done("chiara"), status("chiara"))

	# ---- Rocco's platform and the tram shelter in the square --------------------------------------------------
	await ride("stop_opera", "stop_duomo", true)
	await chat("rocco")
	await chat("ambrogio")
	check("square_on", "Rocco wants to be seen; Ambrogio wants a shelter at the Duomo stop", status("fog_light") == "active" and status("shelter") == "active", "%s, %s" % [status("fog_light"), status("shelter")])
	await ride("stop_duomo", "stop_centrale", true)
	await gather_until("bin", func(): return step_done("shelter", "wire"), [P + "scrap"], 2)
	check("shelter_wire", "old tram wire from the depot's scrap pile", step_done("shelter", "wire"), "copper wire %d" % inv("crystal"))
	await ride("stop_centrale", "stop_duomo", true)
	top_up({"wood": 8, "metal": 2, "crystal": 2}, "a platform, two streetlights, a bench and a sign")
	await walk_to(-27.0, 5.0, 0.8)
	await open_zone("fog_light")
	placed = await put_all([["platform", -28, 8], ["streetlight", -25, 8]])
	check("fog_light_built", "a raised platform for Rocco, with a streetlight", placed == 2 and step_done("fog_light", "platform"), "%d placed" % placed)
	await leave_build()
	await walk_to(-1.0, 25.0, 0.8)
	await open_zone("shelter")
	placed = await put_all([["bench", -2, 28], ["streetlight", 1, 28], ["signpost", 2, 27]])
	await shot("shelter")
	await leave_build()
	check("shelter_built", "a bench, a streetlight and a sign at the Duomo stop", placed == 3 and step_done("shelter", "stop"), "%d placed" % placed)
	await chat("rocco"); await chat("ambrogio")
	check("square_done", "Rocco can be seen, and Ambrogio can see his passengers", done("fog_light") and done("shelter"), "%s, %s" % [status("fog_light"), status("shelter")])

	# ---- Vale's Roman finds -----------------------------------------------------------------------------------
	await chat("vale")
	check("roman_on", "Vale needs a story", status("roman") == "active", status("roman"))
	await walk_to(48.0, 100.0, 1.0)
	await gather_until("dig", func(): return step_done("roman", "finds"), [], 6)
	check("roman_found", "three Roman finds dug up where the metal detector beeps at the building sites", step_done("roman", "finds"), "finds %d" % inv(P + "roman"))
	await chat("vale")
	check("roman_done", "Vale has her story", done("roman"), status("roman"))

	# ---- Ottavio's ducks and Gennaro's stall ------------------------------------------------------------------
	await ride("stop_duomo", "stop_castello", true)
	await chat("ottavio")
	await chat("gennaro")
	check("park_on", "Ottavio's pruning and ducks; Gennaro's new stall", status("ducks") == "active" and status("cart") == "active", "%s, %s" % [status("ducks"), status("cart")])
	if ready_count("chop") < 6: await sleep_until("bench_park1", int(hour() + 4.0) % 24)
	await gather_until("chop", func(): return step_done("ducks", "prune"), [], 12)
	check("ducks_pruned", "six plane trees pruned", step_done("ducks", "prune"), str(game.state.quests.get(P + "ducks", {}).get("progress", {})))
	top_up({"wood": 12, "stone": 4, "clay": 2, "metal": 2, "crystal": 2}, "planks, pillars, roofs, a counter and a lamp")
	await walk_to(-106.5, -124.0, 0.8)
	await open_zone("ducks")
	placed = await put_all([["bridgeDeck", -108, -126, 0, 0.3], ["bridgeDeck", -109, -126, 0, 0.1], ["bridgeDeck", -110, -126, 0, 0.1], ["pillar", -110, -126, 0, 0.25], ["roof", -111, -127, 0, 2.45]])
	await shot("duck_house")
	await leave_build()
	check("ducks_built", "a duck house out on the pond: planks over the water and a roof", step_done("ducks", "house"), "%d of 5 placed" % placed)
	await walk_to(-92.0, -80.0, 0.8)
	await open_zone("cart")
	placed = await put_all([["counter", -94, -84], ["pillar", -94, -86], ["pillar", -93, -86], ["roof", -94, -86, 0, 2.5], ["lamp", -91, -84]])
	await shot("chestnut_stall")
	await leave_build()
	check("cart_built", "a counter, a roof and a lamp for Gennaro's chestnuts", step_done("cart", "stall"), "%d of 5 placed" % placed)
	await chat("ottavio"); await chat("gennaro")
	check("park_done", "the ducks have a house and Gennaro a stall", done("ducks") and done("cart"), "%s, %s" % [status("ducks"), status("cart")])

	# ---- Gino's score, at night -------------------------------------------------------------------------------
	await ride("stop_castello", "stop_opera", true)
	if hour() < 20.0 and hour() > 6.0: await sleep_until("bench_opera", 20)
	await chat("gino")
	check("score_on", "after the opera, Maestro Gino whispers about his lost score", status("score") == "active", "%s at %.1f h" % [status("score"), hour()])
	var pages: Array = Data.layout.nodes.filter(func(n): return n.get("gives", {}).has(P + "score_page"))
	for n in pages:
		if step_done("score", "pages"): break
		if not game.actions.ready(n): continue
		await walk_to(n.x, n.z, 0.6)
		await frames(10)
	check("score_found", "six pages of the score found in the streets at night", step_done("score", "pages"), "pages %d at %.1f h" % [inv(P + "score_page"), hour()])
	await shot("score_page_night")
	await chat("gino")
	check("score_done", "the whole score, back with the prompter", done("score"), status("score"))

	# ---- The evening paper ------------------------------------------------------------------------------------
	var all_done := true
	for q in Data.quests.filter(func(x): return x.id.begins_with(P)):
		if status(q.id.trim_prefix(P)) != "done": all_done = false; note("not done: " + q.id)
	check("all_requests", "all nineteen of Toriano's requests are done", all_done)
	check("radio", "90 column inches: on the radio, and a portable radio in your flat", game.state.flags.get(P + "radio", false), "%d inches" % inches())
	check("front_page", "120 column inches and the Angel lit: the front page on Christmas Day", game.state.flags.get(P + "front_page", false) and LocationMeter.reached(game.state, {"id": P + "front_page"}), "%d inches" % inches())
	await ride("stop_opera", "stop_darsena", true)
	await go("home:spot", "home, to see the radio and the framed front page")
	await shot("flat_with_prizes")
	await tap(KEY_P); await frames(10)
	check("meter_panel", "the progress panel is the evening paper's, with its milestones", game.panels.current == "progress", game.panels.current)
	await shot("la_sera")
	game.panels.close()
