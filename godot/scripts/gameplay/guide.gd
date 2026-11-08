class_name Guide
extends RefCounted
## Runs the guided first day and the one-time tip cards: notices what the player has done, advances the
## Tutorial steps, points the compass, and tells the HUD what to show.

var game
var moved := 0.0
var looked := 0.0
var _last_pos = null
var _last_yaw = null
var buildmode := false

func _init(g) -> void:
	game = g
	game.game_event.connect(_on_event)

func tstate() -> Dictionary: return game.state.tutorial

## Called after a game is loaded or started.
func reset() -> void:
	moved = 0.0; looked = 0.0; _last_pos = null; _last_yaw = null; buildmode = false
	game.hud.apply_reveals(); game.hud.render_guide()

func _on_event(type: String, data: Dictionary) -> void:
	match type:
		"panel":
			var id: String = data.get("id", "")
			if not id in tstate().panels: tstate().panels.append(id)
			tip(id)
		"buildmode":
			if data.get("open", false): buildmode = true; tip("build")
		"minigame": tip(data.get("kind", ""))
		"harmony": tip("harmony")
		"talk": tip("talk")

func update(_dt: float) -> void:
	if game.mode in ["explore", "build"]:
		var p: Vector3 = game.player.pos
		if _last_pos != null:
			var step := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
			if step < 1.0: moved += step   # ignore teleports
		_last_pos = p
		var y: float = game.cam.yaw
		if _last_yaw != null: looked += absf(angle_difference(_last_yaw, y))
		_last_yaw = y
	if not tstate().get("on", false): return
	var done := Tutorial.advance(tstate(), facts())
	if not done.is_empty(): _steps_done()

func facts() -> Dictionary:
	var e: QuestEngine = game.story.engine
	return {"moved": moved, "looked": looked, "flags": game.state.flags, "panels": tstate().panels, "buildmode": buildmode,
		"quests": game.state.quests, "ready": func(q: String) -> bool: return e.is_ready(q),
		"stage": func(q: String) -> int: return e.current_stage(q) if e.status(q) == "active" else -1,
		"objective": func(q: String, i: int) -> bool:
			var quest := Data.quest(q)
			return i < quest.objectives.size() and e.status(q) == "active" and e.objective(q, quest.objectives[i]).done,
		"must": func(q: String, oid: String, i: int) -> bool:
			if e.status(q) != "active": return false
			for o in Data.quest(q).objectives:
				if String(o.get("id", "")) != oid: continue
				if e.objective(q, o).done: return true
				var rows: Array = e.commission(q, o).musts
				return i < rows.size() and rows[i].ok
			return false}

func _steps_done() -> void:
	game.sfx("objective")
	game.hud.apply_reveals()
	game.hud.render_guide(true)
	game.hud.render_tracker()
	if not tstate().on:
		game.banner("You're all set!", "Explore, help your neighbours and grow the kingdom", [], 3.5)
		tip("requests")

## Where the compass points: the guided step's target if it has one, otherwise the tracked request.
func target() -> Dictionary:
	var st := Tutorial.current(tstate())
	var tg: String = st.get("target", "")
	if tg.begins_with("npc:"):
		var a = game.npcs.get(tg.trim_prefix("npc:"))
		if a and a.present: return {"x": a.pos.x, "z": a.pos.z, "label": a.def.name}
	elif tg.begins_with("zone:"):
		var z: Dictionary = Data.zone(tg.trim_prefix("zone:"))
		if not z.is_empty(): return {"x": (z.minI + z.maxI) / 2.0 + 0.5, "z": (z.minK + z.maxK) / 2.0 + 0.5, "label": z.get("name", "")}
	return game.story.tracked_target()

## Shows a tip card the first time something happens (once per save).
func tip(id: String) -> void:
	var tips: Dictionary = Data.tutorial.tips
	if id == "" or not tips.has(id) or id in tstate().seen: return
	tstate().seen.append(id)
	if game.panels.current == id: game.panels.inline_tip(tips[id])   # tips about a panel go inside it
	else: game.hud.show_tip(tips[id])

func skip() -> void:
	if not tstate().get("on", false): return
	tstate().on = false
	game.hud.apply_reveals(); game.hud.render_guide(); game.hud.render_tracker()
	game.toast("Guided day skipped. Tips still pop up the first time you try something new.", "", 4.5)
	tip("requests")
