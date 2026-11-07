extends "res://tests/autoplay_base.gd"

func ui_click(name: String) -> bool:
	await frames(3)
	var n: Control = game.build.ui.find_child(name, true, false)
	if n == null: print("   no UI node ", name); return false
	await click(n.get_global_rect().get_center())
	return true

func point_at(x: float, z: float, y: float = 0.1) -> String:
	game.build.focus = Vector3(x, 0.0, z)
	await settle()
	var p: Vector2 = game.camera.unproject_position(Vector3(x, y, z))
	mouse_move(p); await frames(4)
	return game.build.status_label.text if game.build.status_label else ""

func cell_click(x: float, z: float, y: float = 0.1) -> String:
	var status := await point_at(x, z, y)
	await click(game.camera.unproject_position(Vector3(x, y, z)))
	await frames(3)
	return status

func settle() -> void:
	var last := Vector3.INF
	for n in 120:
		var c: Vector3 = game.camera.global_position
		if c.distance_to(last) < 0.002: return
		last = c; await frames(1)

func count(id: String) -> int:
	return game.state.placements.filter(func(p): return p.id == id).size()

func drafted(id: String = "") -> int:
	return Drafts.of(game.state).filter(func(p): return id == "" or p.id == id).size()

func clashes() -> Array:
	var panels: Array = [game.hud.guide_card, game.hud.tip_card]
	panels.append_array(game.build.ui.find_children("*", "PanelContainer", true, false))
	var out: Array = []
	for i in panels.size():
		for j in range(i + 1, panels.size()):
			var a: Control = panels[i]; var b: Control = panels[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			if a.is_visible_in_tree() and b.is_visible_in_tree() and a.get_global_rect().grow(-2).intersects(b.get_global_rect().grow(-2)): out.append("%s × %s" % [a.name, b.name])
	return out

func spot_counts() -> Dictionary:
	var dry := 0
	var wet := 0
	for cell in game.build.spot_results:
		if game.build.spot_results[cell].is_empty(): continue
		if BuildGrid.ground_at(cell.x, cell.y) >= Heightfield.WALKABLE_MIN: dry += 1
		else: wet += 1
	return {"dry": dry, "wet": wet}

func play() -> void:
	game.state.flags["hasTool"] = true
	game.state.tutorial.on = false; game.hud.apply_reveals()
	game.state.quests["bridge"] = {"status": "active", "progress": {}}
	game.state.inventory["wood"] = 3
	for b in ["bridgeDeck", "bridgePost", "railing"]: game.state.blueprints.append(b)
	game.render_resources()
	game.player.teleport(0.5, -12.5, PI)
	await frames(5)
	var t_walk: float = game.state.time.total
	await frames(30)
	var walking_ran: bool = game.state.time.total > t_walk + 1.0
	await tap(KEY_B)
	await frames(5)
	check("c1", "B at the washout opens build mode there", game.mode == "build" and game.build.current_zone.get("id", "") == "bridge", game.build.current_zone.get("id", "none"))
	var t_build: float = game.state.time.total
	await frames(30)
	check("c2", "The clock runs outside build mode and waits inside it", walking_ran and absf(game.state.time.total - t_build) < 0.001,
		"outside +%.1f min, inside +%.2f min" % [t_build - t_walk, game.state.time.total - t_build])
	game.cam.yaw = 0.35; game.cam.pitch = 1.05; game.cam.dist = 15
	await ui_click("piece_bridgeDeck")
	await point_at(0.5, -14.5)
	await frames(80)
	var sc := spot_counts()
	await shot("spots-plank-from-the-bank")
	check("c3", "With a plank in hand the bank glows where it can go, and the water doesn't yet", game.build.spots_root.visible and sc.dry > 0 and sc.wet == 0,
		"visible=%s dry=%d wet=%d" % [game.build.spots_root.visible, sc.dry, sc.wet])
	for z in [-14.5, -15.5, -16.5]: await cell_click(0.5, z, 0.2)
	await point_at(0.5, -16.5, 0.2)
	await frames(80)
	var reach := spot_counts()
	check("c4", "Three planks built with the wood you have; the glow now reaches out over the water", count("bridgeDeck") == 3 and reach.wet > 0,
		"%d planks, %d spots over water" % [count("bridgeDeck"), reach.wet])
	var too_far := await cell_click(0.5, -17.5, 0.2)
	check("c5", "A plank past its reach is refused, saying why", count("bridgeDeck") == 3 and drafted() == 0 and "post" in too_far, too_far)
	await ui_click("piece_bridgePost")
	var post_status := await cell_click(0.5, -17.5, 0.2)
	check("c6", "A post you can't afford goes into the draft instead of being refused", count("bridgePost") == 0 and drafted("bridgePost") == 1 and "draft" in post_status.to_lower(), post_status)
	await ui_click("piece_bridgeDeck")
	for z in [-17.5, -18.5, -19.5, -21.5, -20.5]: await cell_click(0.5, z, 0.25)
	await shot("drafted-bridge")
	var panel: Control = game.build.ui.find_child("draft_panel", true, false)
	var panel_text := ""
	if panel: for l in panel.find_children("*", "Label", true, false): panel_text += l.text + " | "
	check("c7", "The rest of the crossing drafts onto the drafted post, and the panel lists what's missing", drafted("bridgeDeck") == 5 and count("bridgeDeck") == 3 and "wood" in panel_text,
		"%d decks drafted; %s" % [drafted("bridgeDeck"), panel_text])
	await tap(KEY_B); await frames(5)
	var needs: Control = game.hud.tracker.find_child("draft_needs", true, false)
	var needs_text := ""
	if needs: for l in needs.find_children("*", "Label", true, false): needs_text += l.text + " | "
	await shot("tracker-shopping-list")
	check("c8", "Out of build mode the request tracker shows the shopping list, and the draft stays on the site", game.mode == "explore" and "gather" in needs_text and game.build.draft_root.get_child_count() == drafted(),
		"%s (%d ghosts)" % [needs_text, game.build.draft_root.get_child_count()])
	game.state.inventory["wood"] = 30
	game.render_resources()
	await frames(3)
	await tap(KEY_B); await frames(5)
	game.cam.yaw = 0.35; game.cam.pitch = 1.05; game.cam.dist = 15
	game.build.focus = Vector3(0.5, 0.0, -17.5); await settle()
	await frames(5)
	var overlap := clashes()
	check("c8b", "With the draft bar, the plan panel and the checklist all showing, no boxes overlap", overlap.is_empty() and game.build.ui.find_child("plan_panel", true, false) != null, ", ".join(overlap))
	await ui_click("draft_build")
	await frames(10)
	var stage: int = game.story.engine.current_stage("bridge")
	check("c9", "Build the draft builds it all, bottom up, and the crossing counts", drafted() == 0 and count("bridgeDeck") == 8 and count("bridgePost") == 1 and stage >= 2,
		"drafts left %d, decks %d, posts %d, request step %d" % [drafted(), count("bridgeDeck"), count("bridgePost"), stage])
	await ui_click("piece_railing")
	await cell_click(0.07, -16.5, 0.25)
	await cell_click(0.93, -16.5, 0.25)
	var turns: Array = game.state.placements.filter(func(p): return p.id == "railing").map(func(p): return int(p.r))
	turns.sort()
	await shot("railings-turned-to-the-edge")
	check("c10", "A railing turns to the edge you point at, without pressing R", turns == [1, 3], str(turns))
	await tap(KEY_G); await frames(3)
	var only_on: bool = game.build.draft_only
	await ui_click("piece_railing")
	await cell_click(0.07, -19.5, 0.25)
	var drafted_on_purpose: bool = drafted("railing") == 1 and count("railing") == 2
	key(KEY_CTRL, true); await tap(KEY_Z); key(KEY_CTRL, false); await frames(3)
	var undone := drafted() == 0
	key(KEY_CTRL, true); await tap(KEY_Y); key(KEY_CTRL, false); await frames(3)
	var redone := drafted() == 1
	await tap(KEY_G); await frames(3)
	check("c11", "Draft only drafts what you could afford, and undo and redo work on the draft", only_on and drafted_on_purpose and undone and redone and not game.build.draft_only,
		"draft only=%s drafted=%s undo=%s redo=%s" % [only_on, drafted_on_purpose, undone, redone])
	await cell_click(0.07, -19.5, 0.25)
	check("c12", "Clicking a drafted piece with the same piece in hand builds it", drafted() == 0 and count("railing") == 3, "%d drafted, %d railings" % [drafted(), count("railing")])
	for n in 3:
		if game.mode != "build": break
		await tap(KEY_ESCAPE); await frames(3)
	game.player.teleport(0.5, -13.5, PI)
	game.cam.yaw = 0.0
	await frames(3)
	key(KEY_W, true)
	for n in 120:
		await frames(2)
		if game.player.pos.z < -23.0: break
	key(KEY_W, false)
	check("c13", "The crossing built from the draft can be walked across", game.player.pos.z < -23.0 and game.player.pos.y > -0.3, "z=%.1f y=%.2f" % [game.player.pos.z, game.player.pos.y])
	await shot("crossed")
