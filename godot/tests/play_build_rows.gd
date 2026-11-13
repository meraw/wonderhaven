extends "res://tests/autoplay_base.gd"

func ui_click(name: String) -> bool:
	await frames(3)
	var n: Control = game.build.ui.find_child(name, true, false)
	if n == null:
		note("no UI node %s" % name)
		return false
	await click(n.get_global_rect().get_center())
	return true

func settle() -> void:
	var last := Vector3.INF
	for n in 120:
		var c: Vector3 = game.camera.global_position
		if c.distance_to(last) < 0.002: return
		last = c
		await frames(1)

func look_at(x: float, z: float) -> void:
	game.build.focus = Vector3(x, 0.0, z)
	await settle()

func on_ground(x: float, z: float) -> Vector2:
	return game.camera.unproject_position(Vector3(x, maxf(Heightfield.height(x, z), 0.0) + 0.03, z))

func at_height(x: float, z: float, y: float) -> Vector2:
	return game.camera.unproject_position(Vector3(x, y, z))

func status() -> String:
	return game.build.status_label.text if game.build.status_label else ""

func hover_status(p: Vector2) -> String:
	mouse_move(p)
	await frames(4)
	return status()

var hidden := 0

func drag(points: Array, steps: int = 8, hold: bool = false) -> void:
	if not in_view(points): hidden += 1
	var prev: Vector2 = points[0]
	mouse_move(prev)
	await frames(3)
	mouse_button(prev, MOUSE_BUTTON_LEFT, true)
	await frames(2)
	for n in range(1, points.size()):
		var target: Vector2 = points[n]
		for s in steps:
			mouse_move(prev.lerp(target, float(s + 1) / steps))
			await frames(1)
		prev = target
	await frames(2)
	if not hold: await let_go(prev)

func let_go(p: Vector2) -> void:
	mouse_button(p, MOUSE_BUTTON_LEFT, false)
	await frames(3)

func pieces(id: String) -> Array:
	return game.state.placements.filter(func(p): return p.id == id)

func count(id: String) -> int:
	return pieces(id).size()

func drafted(id: String) -> int:
	return Drafts.of(game.state).filter(func(p): return p.id == id).size()

func free_block(id: String, zone_id: String, cols: int, rows: int) -> Vector2:
	var z: Dictionary = Data.zone(zone_id)
	var ctx: Dictionary = game.placement_ctx()
	for k in range(int(z.minK), int(z.maxK) - rows + 2):
		for i in range(int(z.minI), int(z.maxI) - cols + 2):
			var free := true
			for dk in rows:
				for di in cols:
					for id2 in [id, "fence"]:
						if not BuildGrid.spot(id2, float(i + di), float(k + dk), 0, ctx).ok: free = false
			if free: return Vector2(i, k)
	return Vector2.INF

func undo() -> void:
	key(KEY_CTRL, true)
	await tap(KEY_Z)
	key(KEY_CTRL, false)
	await frames(3)
	await settle()

func redo() -> void:
	key(KEY_CTRL, true)
	await tap(KEY_Y)
	key(KEY_CTRL, false)
	await frames(3)
	await settle()

func in_view(points: Array) -> bool:
	var size: Vector2 = get_viewport().get_visible_rect().size
	for p in points:
		if not Rect2(Vector2.ZERO, size).has_point(p) or game.build._over_ui(p): return false
	return true

func clashes() -> Array:
	var panels: Array = [game.hud.guide_card, game.hud.tip_card]
	panels.append_array(game.build.ui.find_children("*", "PanelContainer", true, false))
	var out: Array = []
	for i in panels.size():
		for j in range(i + 1, panels.size()):
			var a: Control = panels[i]
			var b: Control = panels[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			if a.is_visible_in_tree() and b.is_visible_in_tree() and a.get_global_rect().grow(-2).intersects(b.get_global_rect().grow(-2)): out.append("%s × %s" % [a.name, b.name])
	return out

func lay_bridge() -> void:
	var z: Dictionary = Data.zone("bridge")
	var uid: int = int(game.state.next_uid)
	var parts: Array = [["bridgeDeck", -15, 10.0], ["bridgeDeck", -16, 10.0], ["bridgeDeck", -17, 10.0], ["bridgePost", -18, -1.4], ["bridgeDeck", -18, 0.1], ["bridgeDeck", -19, 0.1], ["bridgeDeck", -20, 0.1], ["bridgeDeck", -22, 0.1], ["bridgeDeck", -21, 0.1]]
	for part in parts:
		var y := BuildGrid.suggest_bottom(String(part[0]), 0.0, float(part[1]), 0, float(part[2]), game.state.placements, z)
		game.commit_place({"uid": uid, "id": String(part[0]), "i": 0.0, "k": float(part[1]), "r": 0, "y": y}, false, false)
		uid += 1

func find_press(id: String, i: int, k: int, y: float) -> Vector2:
	for dz in 12:
		for dx in 12:
			var p := at_height(float(i) + dx * 0.2, float(k) + dz * 0.2, y)
			if not in_view([p]): continue
			mouse_move(p)
			await frames(2)
			var c: Dictionary = game.build.check
			if not c.is_empty() and c.ok and String(c.pl.id) == id and int(c.pl.i) == i and int(c.pl.k) == k: return p
	return Vector2.INF

func floor_top(i: int, k: int) -> float:
	var under: Array = game.state.placements.filter(func(p): return p.id == "floor" and int(p.i) == i and int(p.k) == k)
	return float(under[0].y) + float(Data.piece("floor").h) if not under.is_empty() else -99.0

func build_a_house() -> void:
	var s: Dictionary = game.state
	s.flags["homePlot"] = true
	for b in ["floor", "woodWall", "roof", "hedge"]:
		if not s.blueprints.has(b): s.blueprints.append(b)
	s.inventory["wood"] = 200
	s.inventory["clay"] = 20
	s.inventory["flowers"] = 20
	game.render_resources()
	game.build.color = ""
	await frames(3)
	await tap(KEY_B)
	await frames(5)
	game.cam.yaw = 0.0
	game.cam.pitch = 1.15
	game.cam.dist = 20
	await look_at(18.0, -33.0)
	await ui_click("tab_structure")
	await ui_click("piece_floor")
	var scrub: Array = []
	for row in 4:
		var xs: Array = [15.5, 20.5] if row % 2 == 0 else [20.5, 15.5]
		for x in xs: scrub.append(on_ground(x, -35.5 + row))
	await drag(scrub, 10)
	check("r16", "One zigzag stroke floors a room of twenty-four tiles", count("floor") == 24, "%d tiles" % count("floor"))
	var top := floor_top(15, -36)
	await ui_click("piece_woodWall")
	var sides: Array = []
	for line in [[15.5, -35.8, 20.5, -35.8], [15.2, -35.5, 15.2, -32.5], [20.8, -35.5, 20.8, -32.5], [15.5, -32.2, 20.5, -32.2]]:
		var had := count("woodWall")
		await drag([at_height(line[0], line[1], top), at_height(line[2], line[3], top)], 12)
		sides.append(count("woodWall") - had)
	var standing: bool = pieces("woodWall").all(func(p): return absf(float(p.y) - floor_top(int(p.i), int(p.k))) < 0.01)
	await shot("room-walled")
	check("r17", "Four strokes wall it in, corners closed, every wall standing on the floor", sides == [6, 4, 4, 6] and standing, "north, west, east, south: %s; on the floor %s" % [sides, standing])
	await ui_click("piece_roof")
	var eaves := top + float(Data.piece("woodWall").h)
	for line in [[-36, -35.0], [-34, -33.0]]:
		var from := await find_press("roof", 15, int(line[0]), eaves - 0.1)
		if from != Vector2.INF: await drag([from, at_height(18.0, line[1], eaves), at_height(20.0, line[1], eaves)], 12)
	var roofs: Array = pieces("roof").map(func(p): return "%d,%d" % [int(p.i), int(p.k)])
	roofs.sort()
	check("r18", "Two strokes roof it, the roofs edge to edge on the walls", roofs == ["15,-34", "15,-36", "17,-34", "17,-36", "19,-34", "19,-36"], str(roofs))
	await ui_click("tab_outdoor")
	await ui_click("piece_hedge")
	await drag([on_ground(14.5, -31.5), on_ground(21.5, -31.5), on_ground(21.5, -36.5)], 12)
	var hedges: Array = pieces("hedge")
	var round_the_corner: bool = hedges.all(func(p): return int(p.k) == -32 or int(p.i) == 21)
	await shot("house-in-eight-strokes")
	check("r19", "One stroke runs a hedge along the front and round the corner", hedges.size() == 13 and round_the_corner and status() == "Hedge built", "%d hedges, in an L %s; %s" % [hedges.size(), round_the_corner, status()])
	for n in 3: await undo()
	check("r20", "Three undos take off the hedge and both rows of roof, and the room still stands", count("hedge") == 0 and count("roof") == 0 and count("woodWall") == 20 and count("floor") == 24, "hedges %d, roofs %d, walls %d, floor %d" % [count("hedge"), count("roof"), count("woodWall"), count("floor")])

func play() -> void:
	var s: Dictionary = game.state
	s.flags["hasTool"] = true
	s.tutorial.on = false
	s.tutorial.seen = Data.tutorial.tips.keys()
	game.hud.apply_reveals()
	for b in ["gardenPath", "fence", "bridgeDeck", "bridgePost", "railing"]:
		if not s.blueprints.has(b): s.blueprints.append(b)
	s.inventory["stone"] = 60
	s.inventory["wood"] = 60
	game.render_resources()
	await frames(5)
	await tap(KEY_B)
	await frames(5)
	game.cam.yaw = 0.0
	game.cam.pitch = 1.1
	game.cam.dist = 17
	var zone_id := "plaza"
	var at := free_block("gardenPath", zone_id, 9, 3)
	if at == Vector2.INF:
		zone_id = "village"
		at = free_block("gardenPath", zone_id, 9, 3)
	check("r0", "Build mode is open by a clear patch of the piazza", game.mode == "build" and at != Vector2.INF, "%s at %s" % [zone_id, at])
	if at == Vector2.INF: return
	var i0 := at.x
	var k0 := at.y
	await look_at(i0 + 4.5, k0 + 1.5)
	await ui_click("tab_outdoor")
	await ui_click("piece_gardenPath")
	var hint := await hover_status(on_ground(i0 + 0.5, k0 + 0.5))
	await click(on_ground(i0 + 0.5, k0 + 0.5))
	check("r1", "A click still lays exactly one stone, and the status line says you can drag", count("gardenPath") == 1 and "drag" in hint, "%d stones; %s" % [count("gardenPath"), hint])
	var shaky := on_ground(i0 + 1.5, k0 + 0.5)
	await drag([shaky, shaky + Vector2(4, 3)], 2)
	check("r2", "A click with a shaky hand lays one stone, not two", count("gardenPath") == 2, "%d stones" % count("gardenPath"))
	await drag([on_ground(i0 + 2.5, k0 + 0.5), on_ground(i0 + 7.5, k0 + 0.5)], 12, true)
	var mid := status()
	await shot("dragging-paving")
	await let_go(on_ground(i0 + 7.5, k0 + 0.5))
	var row: Array = pieces("gardenPath")
	var cols: Array = row.map(func(p): return int(p.i) - int(i0))
	cols.sort()
	var level: bool = row.all(func(p): return int(p.k) == int(k0) and absf(float(p.y) - BuildGrid.ground_at(float(p.i), float(p.k))) < 0.01)
	check("r3", "Holding the button and dragging paves every tile on the way, flat on the ground", cols == [0, 1, 2, 3, 4, 5, 6, 7] and level, "tiles %s, level %s" % [cols, level])
	check("r4", "While you drag, the status line counts what you've laid", "6" in mid and "Dragging" in mid, mid)
	var yaw_before: float = game.cam.yaw
	await undo()
	var after_undo := count("gardenPath")
	await redo()
	check("r5", "One undo takes the whole drag back, one redo relays it", after_undo == 2 and count("gardenPath") == 8, "%d after undo, %d after redo" % [after_undo, count("gardenPath")])
	check("r5b", "Ctrl+Z and Ctrl+Y leave the view where it was", absf(game.cam.yaw - yaw_before) < 0.001, "the view turned %.2f rad" % (game.cam.yaw - yaw_before))
	var later := await hover_status(on_ground(i0 + 0.5, k0 + 1.5))
	check("r6", "Once you've dragged a row the status line stops mentioning it", "Click to build" in later and not "drag" in later, later)
	await drag([on_ground(i0 + 8.5, k0 + 0.5), on_ground(i0 + 0.5, k0 + 0.5)], 12)
	var stacked: int = pieces("gardenPath").filter(func(p): return absf(float(p.y) - BuildGrid.ground_at(float(p.i), float(p.k))) > 0.01).size()
	check("r7", "Dragging back over the paved row adds only the one free tile, and stacks nothing", count("gardenPath") == 9 and stacked == 0, "%d stones, %d stacked" % [count("gardenPath"), stacked])
	var fast_from := on_ground(i0 + 0.5, k0 + 1.5)
	var fast_to := on_ground(i0 + 6.5, k0 + 1.5)
	mouse_move(fast_from)
	await frames(3)
	mouse_button(fast_from, MOUSE_BUTTON_LEFT, true)
	await frames(1)
	var began := Time.get_ticks_usec()
	mouse_move(fast_to)
	await frames(2)
	note("six stones laid in one sweep: %d ms for the two frames" % int((Time.get_ticks_usec() - began) / 1000.0))
	await let_go(fast_to)
	var second: Array = pieces("gardenPath").filter(func(p): return int(p.k) == int(k0) + 1).map(func(p): return int(p.i) - int(i0))
	second.sort()
	check("r8", "A sweep too fast to touch every tile still leaves no gap", second == [0, 1, 2, 3, 4, 5, 6], str(second))
	await ui_click("tab_structure")
	await ui_click("piece_fence")
	var fk := k0 + 2.0
	var wobble: Array = [on_ground(i0 + 0.5, fk + 0.08)]
	for n in range(1, 7): wobble.append(on_ground(i0 + n + 0.5, fk + (0.85 if n % 2 == 1 else 0.1)))
	await drag(wobble, 6)
	var fence: Array = pieces("fence")
	var turns := {}
	var rows := {}
	for p in fence:
		turns[int(p.r)] = true
		rows[int(p.k)] = true
	var fcols: Array = fence.map(func(p): return int(p.i) - int(i0))
	fcols.sort()
	await shot("fence-row")
	check("r9", "A fence dragged with a wobbly hand runs straight along the edge it began on", fcols == [0, 1, 2, 3, 4, 5, 6] and turns.size() == 1 and rows.size() == 1, "tiles %s, edges %s, rows %s" % [fcols, turns.keys(), rows.keys()])
	var resting := status()
	var ghost_hidden: bool = game.build.ghost == null or not game.build.ghost.visible
	var moved_on := await hover_status(on_ground(i0 + 7.5, fk + 0.5))
	var ghost_back: bool = game.build.ghost != null and game.build.ghost.visible
	check("r9b", "With the cursor still on the fence just built, the status says so and no red outline covers it", resting == "Fence built" and ghost_hidden and moved_on != resting and ghost_back, "resting: %s (outline hidden %s); moved on: %s (outline back %s)" % [resting, ghost_hidden, moved_on, ghost_back])
	await undo()
	s.inventory["wood"] = 2
	game.render_resources()
	await frames(3)
	await drag([on_ground(i0 + 0.5, fk + 0.08), on_ground(i0 + 4.5, fk + 0.08)], 10)
	check("r10", "When the wood runs out mid-drag, the rest of the row goes into the draft", count("fence") == 2 and drafted("fence") == 3, "%d built, %d drafted" % [count("fence"), drafted("fence")])
	s.inventory["wood"] = 30
	game.render_resources()
	await frames(3)
	await drag([on_ground(i0 + 2.5, fk + 0.08), on_ground(i0 + 4.5, fk + 0.08)], 8)
	check("r11", "With wood again, dragging along the drafted pieces builds them", count("fence") == 5 and drafted("fence") == 0, "%d built, %d drafted" % [count("fence"), drafted("fence")])
	await tap(KEY_ESCAPE)
	await frames(3)
	var target: Dictionary = pieces("fence")[0]
	var fb := BuildGrid.bounds(target)
	await click(at_height((fb.minX + fb.maxX) / 2.0, (fb.minZ + fb.maxZ) / 2.0, fb.top))
	await frames(3)
	var picked: bool = game.build.selected == int(target.uid)
	await tap(KEY_T)
	await frames(3)
	var paint := String(target.get("color", ""))
	var overlap := clashes()
	var reach_all := true
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for sw in game.build.ui.find_child("swatches", true, false).get_children():
		if not screen.encloses((sw as Control).get_global_rect()): reach_all = false
	await shot("another-like-it")
	await ui_click("pick_same")
	await frames(3)
	var in_hand: bool = game.build.item_id == "fence" and game.build.rotation == int(target.r) and game.build.color == paint and game.build.selected == -1
	await click(on_ground(i0 + 6.5, fk + 0.08))
	var copy: Array = pieces("fence").filter(func(p): return int(p.i) == int(i0) + 6)
	check("r12", "Build another like it puts the same piece in your hand, turned and painted the same", picked and paint != "" and in_hand and overlap.is_empty() and copy.size() == 1 and String(copy[0].get("color", "")) == paint and int(copy[0].r) == int(target.r),
		"picked %s, paint %s, in hand %s, overlaps %s, copies %d" % [picked, paint, in_hand, overlap, copy.size()])
	check("r12b", "Every colour of a selected piece's palette is on screen to click", reach_all, "all twelve swatches inside the window: %s" % reach_all)
	await drag([on_ground(i0 + 4.5, fk + 0.08), on_ground(i0 + 8.5, fk + 0.08)], 10)
	var carried: Array = pieces("fence").map(func(p): return int(p.i) - int(i0))
	carried.sort()
	var one_edge: bool = pieces("fence").all(func(p): return int(p.r) == int(target.r) and int(p.k) == int(fk))
	check("r12c", "A row begun on a spot that's already taken carries on along the same edge", carried == [0, 1, 2, 3, 4, 5, 6, 7, 8] and one_edge, "tiles %s, one edge %s" % [carried, one_edge])
	await click(on_ground(i0 + 0.08, fk + 0.5))
	var corner: Array = pieces("fence").filter(func(p): return int(p.i) == int(i0) and int(p.k) == int(fk))
	var turned := {}
	for p in corner: turned[int(p.r)] = true
	check("r12d", "Two fences meet at the corner of one tile", corner.size() == 2 and turned.size() == 2, "%d fences on the corner tile, edges %s; %s" % [corner.size(), turned.keys(), status()])
	await shot("fence-corner")
	await tap(KEY_B)
	await frames(5)
	lay_bridge()
	game.player.teleport(0.5, -12.5, PI)
	await frames(5)
	await tap(KEY_B)
	await frames(5)
	game.cam.yaw = 0.35
	game.cam.pitch = 1.2
	game.cam.dist = 24
	await look_at(0.5, -16.5)
	var deck_top := func(k: int) -> float:
		var deck: Array = game.state.placements.filter(func(p): return p.id == "bridgeDeck" and int(p.i) == 0 and int(p.k) == k)
		return float(deck[0].y) + float(Data.piece("bridgeDeck").h) if not deck.is_empty() else -99.0
	await ui_click("tab_structure")
	await ui_click("piece_railing")
	var top: float = deck_top.call(-16)
	await drag([at_height(0.93, -15.5, top + 0.05), at_height(0.93, -20.5, top + 0.05)], 14)
	var rails: Array = pieces("railing")
	var ks: Array = rails.map(func(p): return int(p.k))
	ks.sort()
	var on_deck: bool = rails.all(func(p): return int(p.i) == 0 and int(p.r) == 1 and absf(float(p.y) - float(deck_top.call(int(p.k)))) < 0.02)
	await shot("railings-along-the-bridge")
	check("r13", "Railings dragged along the bridge stand on its deck, one a plank, all on the same side", ks == [-21, -20, -19, -18, -17, -16] and on_deck, "planks %s, on deck %s" % [ks, on_deck])
	await ui_click("piece_bridgeDeck")
	var before := count("bridgeDeck")
	await drag([on_ground(-1.5, -14.5), at_height(-1.5, -20.5, 0.2)], 14)
	var reach: Array = pieces("bridgeDeck").filter(func(p): return int(p.i) == -2).map(func(p): return int(p.k))
	reach.sort()
	check("r14", "Planks dragged out from the bank stop where their reach ends, and nothing is drafted past it", count("bridgeDeck") - before == reach.size() and reach.size() >= 2 and reach.size() <= 4 and drafted("bridgeDeck") == 0, "planks at %s, %s" % [reach, status()])
	await shot("planks-to-their-reach")
	await tap(KEY_B)
	await frames(5)
	await build_a_house()
	check("r21", "Every drag began and ended on open ground, clear of the panels", hidden == 0, "%d drags reached under a panel" % hidden)
