extends "res://tests/full_base.gd"

var events: Array = []

func of(type: String) -> Array: return events.filter(func(e): return e.type == type)

func choices_up(id: String) -> void:
	var a = game.npcs[id]
	game.player.teleport(a.pos.x + 0.5, a.pos.z + 1.9, atan2(-0.5, -1.9)); game.cam.snap(); await frames(5)
	await tap(KEY_E)
	for n in 80:
		await frames(4)
		if not game.dialogue.choices.is_empty(): return
		if game.mode == "dialogue": await tap(KEY_E)

func pick(kind: String) -> bool:
	var i: int = game.dialogue.choices.map(func(o): return o.get("kind", "")).find(kind)
	if i < 0: return false
	await tap(game.dialogue.key_for(i))
	return true

func press(name: String) -> bool:
	var b := game.panels.find_child(name, true, false) as Button
	if b == null or b.disabled: return false
	await click(b.get_global_rect().get_center())
	await frames(6)
	return true

func open_shop() -> bool:
	await choices_up("bram")
	if not await pick("shop"): return false
	for n in 60:
		await frames(4)
		if game.panels.current == "shop": return true
		if game.mode == "dialogue" and game.dialogue.choices.is_empty(): await tap(KEY_E)
	return false

func buy(test: Callable) -> bool:
	for e in Shop.stock(game.state, "bram"):
		if not test.call(e): continue
		var b := game.panels.find_child("buy_%d" % int(e.i), true, false) as Button
		if b == null: return false
		var sc: Node = b.get_parent()
		while sc != null and not sc is ScrollContainer: sc = sc.get_parent()
		if sc: (sc as ScrollContainer).ensure_control_visible(b)
		await frames(3)
		return await press("buy_%d" % int(e.i))
	return false

func leave() -> void:
	for n in 6:
		if game.mode == "explore": return
		await tap(KEY_ESCAPE); await frames(6)

func put(id: String, i: float, k: float, hit: float = 10.0) -> bool:
	var zone := BuildGrid.zone_at(game.placement_ctx().zones, i, k)
	var pl := {"uid": int(game.state.next_uid), "id": id, "i": i, "k": k, "r": 0, "y": BuildGrid.suggest_bottom(id, i, k, 0, hit, game.state.placements, zone)}
	game.state.next_uid = int(pl.uid) + 1
	var r: Dictionary = game.commit_place(pl, false, true)
	if not r.ok: note("%s at %d,%d: %s" % [id, i, k, r.get("reason", "")])
	return r.ok

func start_at(id: String) -> bool:
	var n := Data.node_def(id)
	var p: Vector3 = game.player.pos
	var d := maxf(0.01, Vector2(p.x - n.x, p.z - n.z).length())
	await walk_to(n.x + (p.x - n.x) / d * 1.9, n.z + (p.z - n.z) / d * 1.9, 0.6)
	if not await face_and_press(id, n.x, n.z): return false
	await frames(6)
	return true

func strike_perfect() -> void:
	for n in 600:
		await frames(1)
		var a: Dictionary = game.minigame.active
		if a.is_empty(): return
		var mg = a.mg
		if mg.done:
			await frames(2)
			await shot("perfect-run")
			for m in 40:
				await frames(1)
				if game.minigame.active.is_empty(): return
			return
		if mg.pause > 0.0: continue
		mg.r = (float(mg.target[0]) + float(mg.target[1])) / 2.0 + float(mg.speed) * 0.05
		await tap(KEY_E)

func play() -> void:
	var s: Dictionary = game.state
	for q in ["tool", "bridge", "workshop"]: s.quests[q] = {"status": "done", "progress": {}}
	for fl in ["hasTool", "toolGiven", "orchardOpen", "workshopDone"]: s.flags[fl] = true
	s.tutorial.on = false; game.hud.apply_reveals()
	s.time.minute = 9 * 60.0
	s.inventory.merge({"coins": 900, "metal": 10, "wood": 6, "crystal": 2}, true)
	game.render_resources()
	for a in game.npcs.values(): a.teleport_home()
	game.game_event.connect(func(type, data): events.append({"type": type, "data": data}))
	await frames(10)

	await start_at("bigoak0")
	await frames(4)
	var label: String = game.actions.node_label(Data.node_def("bigoak0"))
	await shot("big-oak-too-big")
	check("k1", "The old hatchet can't fell a big oak, and the toast says who sells a bigger axe", game.mode != "minigame" and of("too_big").size() == 1 and label.contains("old hatchet"), label)

	var opened := await open_shop()
	await frames(10)
	await shot("elio-sells-tools")
	var metal0 := inv("metal")
	var bought := await buy(func(e): return e.kind == "tool" and e.id == "axe")
	check("k2", "Elio sells the steel axe for lire and metal, with the oak beam's plan", opened and bought and Tools.level(s, "axe") == 2 and s.blueprints.has("oakBeam") and inv("metal") == metal0 - 2,
		"axe %d, metal %d→%d, plan %s" % [Tools.level(s, "axe"), metal0, inv("metal"), s.blueprints.has("oakBeam")])
	await leave()

	var beams0 := inv("beam")
	await start_at("bigoak0")
	var axe_shown: String = ""
	var tn: Node = game.minigame.find_child("tool_name", true, false)
	if tn: axe_shown = tn.text
	await shot("felling-a-big-oak")
	if game.mode == "minigame": await play_minigame()
	await frames(20)
	check("k3", "With the steel axe the big oak comes down, for beams as well as wood", axe_shown.contains("Steel axe") and inv("beam") > beams0, "panel '%s', beams %d→%d, wood %d" % [axe_shown, beams0, inv("beam"), inv("wood")])

	opened = await open_shop()
	bought = await buy(func(e): return e.kind == "tool" and e.id == "pick")
	check("k4", "Then the pick and chisel, with the stone arch and column plans", opened and bought and Tools.level(s, "pick") == 2 and s.blueprints.has("stoneArch") and s.blueprints.has("column"), "pick %d" % Tools.level(s, "pick"))
	await leave()

	var cut0 := inv("cutstone")
	var stone0 := inv("stone")
	var p: Vector3 = game.player.pos
	var rocks: Array = Data.layout.nodes.filter(func(n): return n.kind == "mine" and game.actions.ready(n))
	rocks.sort_custom(func(a, b): return Vector2(a.x - p.x, a.z - p.z).length() < Vector2(b.x - p.x, b.z - p.z).length())
	var struck := await start_at(String(rocks[0].id))
	if struck and game.mode == "minigame": await strike_perfect()
	await frames(20)
	var run: Array = of("perfect_run")
	check("k5", "A perfect run at the quarry pays a bonus, and the chisel dresses a block of cut stone from every perfect strike", struck and run.size() == 1 and inv("cutstone") - cut0 == 4 and inv("stone") - stone0 >= 1 + 3 + 1 + 1 + int(Data.tools.perfect_bonus),
		"cut stone %d→%d, stone %d→%d, %s" % [cut0, inv("cutstone"), stone0, inv("stone"), str(run.map(func(e): return e.data.reward))])

	opened = await open_shop()
	var coins0 := inv("coins")
	for n in 6:
		if inv("beam") >= 8: break
		await buy(func(e): return e.kind == "items" and e.items.has("beam"))
	for n in 10:
		if inv("cutstone") >= 18: break
		await buy(func(e): return e.kind == "items" and e.items.has("cutstone"))
	check("k6", "Beams and cut stone can be bought with lire instead", opened and inv("beam") >= 8 and inv("cutstone") >= 18 and inv("coins") < coins0, "beams %d, cut stone %d, lire %d→%d" % [inv("beam"), inv("cutstone"), coins0, inv("coins")])
	await leave()

	var beam_ok := true
	for k in [-15, -16, -17, -18, -19, -22, -21, -20]:
		if not await put("oakBeam", 1, k): beam_ok = false
	var walkable: bool = Validate.path_across(Data.zone("bridge"), game.walk).ok
	check("k7", "Oak beams cross the washout from bank to bank without a single post", beam_ok and walkable and not s.placements.any(func(q): return q.id in ["bridgePost", "column"]), "placed %s, walkable %s" % [beam_ok, walkable])

	var arch_ok := true
	for k in [-15, -16, -17, -18]:
		if not await put("stoneArch", -2, k): arch_ok = false
	if not await put("column", -2, -19, -1.4): arch_ok = false
	for k in [-19, -22, -21, -20]:
		if not await put("stoneArch", -2, k): arch_ok = false
	var arches: int = s.placements.filter(func(q): return q.id == "stoneArch").size()
	check("k8", "Stone arches reach three tiles out, and a stone column in the stream holds up the rest", arch_ok and arches == 8, "%d arches, column %s" % [arches, s.placements.any(func(q): return q.id == "column")])
	game.player.teleport(4.0, -12.8, PI * 0.85); game.cam.yaw = 0.55; game.cam.pitch = 0.6; game.cam.dist = 11.0; game.cam.snap()
	await frames(10)
	await shot("oak-and-stone-crossings")

	await tap(KEY_I); await frames(8)
	var axe_line: Node = game.panels.find_child("tool_axe", true, false)
	var pick_line: Node = game.panels.find_child("tool_pick", true, false)
	await shot("bag-tools")
	check("k9", "The bag lists your tools, what they do and the next one to buy", axe_line != null and String(axe_line.text).contains("Steel axe") and String(axe_line.text).contains("Woodcutter's axe") and pick_line != null and String(pick_line.text).contains("Pick and chisel"),
		"%s / %s" % [axe_line.text if axe_line else "-", pick_line.text if pick_line else "-"])
	await leave()

	await walk_direct(1.5, -13.6, 0.4)
	await walk_direct(1.5, -24.0, 0.7)
	check("k10", "And you can walk across on the oak beams", game.player.pos.z < -23.0 and game.player.pos.y > -0.3, "z=%.1f y=%.2f" % [game.player.pos.z, game.player.pos.y])
