extends Node3D
## The game: owns the scene, systems and modes, and runs the main loop.

var decor: Dictionary
var statics: Array
var walk: WalkWorld
var village: Village
var effects: Effects
var player_char: Chibi
var player: PlayerController
var cam: FollowCamera
var camera: Camera3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var ui: CanvasLayer
var theme_res: Theme
var prompt_panel: PanelContainer
var prompt_label: Label
var hotkeys: Label
var state: Dictionary = {}
var ui_root: Control
var toasts: VBoxContainer
var hud_res: HBoxContainer
var build: BuildMode
var piece_root := Node3D.new()
var piece_nodes: Dictionary = {}
var spawn_anims: Array = []
var mech: Dictionary = {"powered": {}, "watered": {}, "pumps": {}, "sources": {}, "fed": {}, "lamps": {}, "fountains": {}}
var sitting := {}
var drag_moved := false
var _drag_dist := 0.0
signal game_event(type: String, data: Dictionary)
var mode := "explore"
var time := 0.0
var interactables: Array = []
var target = null
var dragging := false
var shot_cfg := {}

func _ready() -> void:
	Controls.setup()
	theme_res = UiTheme.build()
	state = GameState.new_game()
	decor = WorldStatics.generate_decor()
	statics = WorldStatics.build_statics(decor)
	walk = WalkWorld.new(statics, func(f): return state.flags.get(f, false))
	env = TerrainBuilder.build_environment(); add_child(env)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_energy = 0.62; sun.light_color = Color("fff1d6")
	sun.directional_shadow_max_distance = 60.0; sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)
	village = Village.new(); village.name = "Village"; add_child(village); village.build(decor)
	effects = Effects.new(); add_child(effects)
	player_char = Chibi.new(Data.appearance["default"]); player_char.name = "Player"; add_child(player_char)
	var sp: Dictionary = Data.layout.spawn
	player = PlayerController.new(player_char, walk, sp.x, sp.z, sp.yaw)
	walk.dynamic.append(player.body)
	camera = Camera3D.new(); camera.fov = 45; camera.far = 500; add_child(camera); camera.current = true
	cam = FollowCamera.new(camera)
	piece_root.name = "Placements"; add_child(piece_root)
	_build_ui()
	build = BuildMode.new(); build.name = "BuildMode"; add_child(build); build.setup(self)
	_register_world_interactables()
	_parse_args()
	cam.update(0.016, player.pos); cam.snap()
	if shot_cfg.has("autoplay"):
		var script: Script = load(shot_cfg.autoplay)
		if script == null or not script.can_instantiate():
			push_error("Autoplay script failed to load: %s" % shot_cfg.autoplay); get_tree().quit(2); return
		var runner = script.new()
		add_child(runner)
		runner.call_deferred("run", self)

func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = theme_res; root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	prompt_panel = UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 999)
	prompt_label = UiTheme.label("", 18)
	prompt_panel.add_child(prompt_label)
	var pc := CenterContainer.new(); pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.anchor_left = 0; pc.anchor_right = 1; pc.anchor_top = 1; pc.anchor_bottom = 1; pc.offset_top = -150; pc.offset_bottom = -100
	pc.add_child(prompt_panel); prompt_panel.visible = false
	root.add_child(pc)
	var hk := UiTheme.panel()
	hotkeys = UiTheme.label("", 13, UiTheme.INK2)
	hk.add_child(hotkeys)
	hk.anchor_top = 1; hk.anchor_bottom = 1; hk.offset_left = 14; hk.offset_top = -56; hk.offset_bottom = -14; hk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hk)
	ui_root = root
	toasts = VBoxContainer.new(); toasts.anchor_left = 0.5; toasts.anchor_right = 0.5; toasts.offset_left = -300; toasts.offset_right = 300; toasts.offset_top = 70
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN; toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(toasts)
	var rp := UiTheme.panel(); rp.position = Vector2(14, 14); rp.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(rp)
	hud_res = HBoxContainer.new(); hud_res.add_theme_constant_override("separation", 8); rp.add_child(hud_res)
	render_resources()

func add_interactable(rec: Dictionary) -> void:
	var r := {"radius": 1.8, "priority": 0.0, "available": func(): return true}
	r.merge(rec, true)
	interactables.append(r)

func _register_world_interactables() -> void:
	for f in Data.layout.features:
		if f.kind == "sign":
			var text: String = f.text
			add_interactable({"id": f.id, "x": f.x, "z": f.z, "object": village.objects[f.id], "label": func(): return "Read sign", "act": func(): toast(text)})

func toast(text: String, kind: String = "", life: float = 2.8) -> void:
	print("[toast] ", text)
	var bg := Color("effff4") if kind == "good" else (Color("fff0f0") if kind == "warn" else UiTheme.CREAM)
	var bd := Color("9fe0b5") if kind == "good" else (Color("ffb3b3") if kind == "warn" else UiTheme.LINE)
	var p := UiTheme.panel(bg, bd, 999)
	var l := UiTheme.label(text, 15, Color("2f8a52") if kind == "good" else (Color("b34a4a") if kind == "warn" else UiTheme.INK))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if text.length() > 70: l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 560
	p.add_child(l); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := CenterContainer.new(); c.add_child(p); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(c)
	while toasts.get_child_count() > 5: toasts.get_child(0).queue_free(); toasts.remove_child(toasts.get_child(0))
	var tw := create_tween(); tw.tween_interval(life); tw.tween_property(c, "modulate:a", 0.0, 0.4); tw.tween_callback(c.queue_free)

func emit_event(type: String, data: Dictionary = {}) -> void:
	game_event.emit(type, data)

func sfx(_name: String) -> void:
	pass

func render_resources(pop: Array = []) -> void:
	for c in hud_res.get_children(): c.queue_free()
	for id in Data.resource_order:
		var n: int = int(state.inventory.get(id, 0))
		if id != "spark" and n <= 0: continue
		var chip := UiTheme.panel(Color("fff7cf") if id == "spark" else Color.WHITE, UiTheme.GOLD if id == "spark" else Color("f3dfc0"), 999)
		chip.name = "res_" + id
		var l := UiTheme.label("%s %d" % [Data.resources[id].icon, n], 15)
		chip.add_child(l)
		hud_res.add_child(chip)
		if pop.has(id):
			chip.pivot_offset = Vector2(30, 14)
			var tw := chip.create_tween(); tw.tween_property(chip, "scale", Vector2(1.3, 1.3), 0.12); tw.tween_property(chip, "scale", Vector2.ONE, 0.25)

func give(items: Dictionary, source = null, quiet: bool = false) -> void:
	Inventory.add(state.inventory, items)
	render_resources(items.keys())
	if not quiet:
		for id in items:
			if items[id] > 0: toast("+%d %s %s" % [items[id], Data.resources[id].icon, Data.resources[id].name], "good", 1.8)
	if source is Vector3: effects.sparkle(source, 10)
	emit_event("gain", {"items": items})

# ---- Zones and blueprints
func zone_unlocked(zone: Dictionary) -> bool:
	var u: Dictionary = zone.get("unlock", {})
	if u.has("flag") and not state.flags.get(u.flag, false): return false
	if u.has("quest") and not state.quests.has(u.quest): return false
	return true

func zone_plan_visible(zone: Dictionary) -> bool:
	if not zone_unlocked(zone): return false
	var u: Dictionary = zone.get("unlock", {})
	if u.has("quest") and state.quests.get(u.quest, {}).get("status", "") != "active": return false
	if zone.id == "dock" and state.flags.get("boatReady", false): return false
	return true

func blueprint_hint(id: String) -> String:
	if has_method("_story_hint"): return call("_story_hint", id)
	return "Keep helping the villagers to discover this blueprint"

func build_goals(_zone: Dictionary) -> Dictionary:
	return {}

# ---- Construction
func placement_ctx(placements = null) -> Dictionary:
	var bodies := [{"x": player.pos.x, "z": player.pos.z, "r": 0.3, "y": player.pos.y}]
	return {"placements": placements if placements != null else state.placements, "zones": Data.layout.zones.filter(func(z): return zone_unlocked(z)),
		"locked_zones": Data.layout.zones.filter(func(z): return not zone_unlocked(z)), "harmony": state.harmony, "statics": statics, "flags": state.flags, "bodies": bodies}

func commit_place(pl: Dictionary, animate: bool = true, check_cost: bool = true) -> Dictionary:
	var others: Array = state.placements.filter(func(p): return p.uid != pl.uid)
	var v := BuildGrid.validate_placement(pl, placement_ctx(others))
	if not v.ok: return v
	var cost: Dictionary = Data.piece(pl.id).cost
	if check_cost and not Inventory.can_afford(state.inventory, cost): return {"ok": false, "reason": "Not enough materials"}
	if check_cost: Inventory.spend(state.inventory, cost)
	state.placements.append(pl)
	state.next_uid = maxi(int(state.next_uid), int(pl.uid) + 1)
	state.stats.placed += 1
	_add_piece_node(pl, animate)
	if animate: player_char.play("build"); sfx("place")
	render_resources(cost.keys())
	on_build_changed({"action": "place", "pl": pl, "zone": v.zone})
	return {"ok": true}

func commit_remove(uid: int, refund: bool = true) -> Dictionary:
	var v := BuildGrid.validate_removal(uid, placement_ctx())
	if not v.ok: return v
	var pl := {}
	for p in state.placements:
		if p.uid == uid: pl = p
	state.placements = state.placements.filter(func(p): return p.uid != uid)
	if refund: Inventory.add(state.inventory, Data.piece(pl.id).cost)
	var n: Node3D = piece_nodes.get(uid)
	if n: effects.poof(n.position, Color("e9ddff")); n.queue_free(); piece_nodes.erase(uid)
	sfx("remove")
	render_resources(Data.piece(pl.id).cost.keys())
	on_build_changed({"action": "remove", "pl": pl})
	return {"ok": true}

func commit_move(uid: int, to: Dictionary) -> Dictionary:
	var pl := {}
	for p in state.placements:
		if p.uid == uid: pl = p
	if pl.is_empty(): return {"ok": false, "reason": "That piece is gone"}
	var cand := pl.duplicate(true); cand.merge(to, true)
	var others: Array = state.placements.filter(func(p): return p.uid != uid)
	if to.i != pl.i or to.k != pl.k or to.y != pl.y:
		var rm := BuildGrid.validate_removal(uid, placement_ctx())
		if not rm.ok: return rm
	var v := BuildGrid.validate_placement(cand, placement_ctx(others))
	if not v.ok: return v
	pl.merge(to, true)
	_sync_piece(pl)
	effects.sparkle(piece_nodes[uid].position + Vector3(0, 0.4, 0), 8, Color("c9a8ff"))
	sfx("place")
	on_build_changed({"action": "move", "pl": pl, "zone": v.zone})
	return {"ok": true}

func commit_recolor(uid: int, color: String) -> Dictionary:
	var pl := {}
	for p in state.placements:
		if p.uid == uid: pl = p
	if pl.is_empty(): return {"ok": false, "reason": "That piece is gone"}
	if color == "": pl.erase("color")
	else: pl["color"] = color
	PieceMeshes.set_color(piece_nodes[uid], color if color != "" else Data.piece(pl.id).color)
	effects.sparkle(piece_nodes[uid].position + Vector3(0, 0.5, 0), 10, Color(color) if color != "" else Color.WHITE)
	sfx("paint")
	on_build_changed({"action": "recolor", "pl": pl})
	return {"ok": true}

func toggle_lever(uid: int) -> void:
	for p in state.placements:
		if p.uid == uid:
			var st: Dictionary = p.get("state", {}); st["on"] = not st.get("on", false); p["state"] = st
	sfx("lever")
	on_build_changed({"action": "switch"})

func _add_piece_node(pl: Dictionary, animate: bool) -> void:
	var n := PieceMeshes.make(pl.id, pl.get("color", ""))
	n.set_meta("uid", pl.uid)
	piece_root.add_child(n); piece_nodes[pl.uid] = n
	_sync_piece(pl)
	if animate:
		n.scale = Vector3.ONE * 0.01
		var tw := n.create_tween(); tw.tween_property(n, "scale", Vector3.ONE * 1.15, 0.22).set_trans(Tween.TRANS_BACK); tw.tween_property(n, "scale", Vector3.ONE, 0.12)
		effects.magic(n.position, minf(2.0, float(Data.piece(pl.id).h) + 0.5))

func _sync_piece(pl: Dictionary) -> void:
	var n: Node3D = piece_nodes.get(pl.uid)
	if n == null: return
	var fp := BuildGrid.footprint(Data.piece(pl.id), int(pl.r))
	n.position = Vector3(pl.i + fp.x / 2.0, pl.y, pl.k + fp.y / 2.0)
	n.rotation.y = -int(pl.r) * PI / 2.0

func rebuild_all_pieces() -> void:
	for c in piece_root.get_children(): c.queue_free()
	piece_nodes.clear()
	for pl in state.placements: _add_piece_node(pl, false)
	on_build_changed({"action": "load"})

func on_build_changed(ev: Dictionary) -> void:
	walk.surfaces = BuildGrid.surfaces_for(state.placements)
	var F: Dictionary = Data.layout.fountain
	mech = Mechanics.solve(state.placements, [{"id": "fountain", "cell": F.inlet.cell, "side": F.inlet.side}])
	_refresh_piece_interactables()
	build.refresh_plan()
	emit_event("build", ev)

func _refresh_piece_interactables() -> void:
	interactables = interactables.filter(func(it): return not it.get("piece", false))
	for pl in state.placements:
		var d := Data.piece(pl.id)
		if not d.has("interact"): continue
		var b := BuildGrid.bounds(pl)
		var rec := {"id": "pl:%d" % pl.uid, "piece": true, "x": (b.minX + b.maxX) / 2.0, "z": (b.minZ + b.maxZ) / 2.0, "radius": 1.3, "object": piece_nodes.get(pl.uid)}
		var ppl: Dictionary = pl
		match d.interact:
			"door":
				rec["label"] = func(): return "Close door" if ppl.get("state", {}).get("open", false) else "Open door"
				rec["act"] = func():
					var st: Dictionary = ppl.get("state", {}); st["open"] = not st.get("open", false); ppl["state"] = st
					sfx("door"); walk.surfaces = BuildGrid.surfaces_for(state.placements)
			"lever":
				rec["label"] = func(): return "Switch lever off" if ppl.get("state", {}).get("on", false) else "Switch lever on"
				rec["act"] = func(): toggle_lever(ppl.uid)
			"sit":
				rec["label"] = func(): return "Sit down"
				rec["act"] = func(): sit_on(ppl)
			"sleep":
				rec["label"] = func(): return "Rest until morning"
				rec["act"] = func(): if has_method("rest"): call("rest")
		if rec.has("act"): add_interactable(rec)

func sit_on(pl: Dictionary) -> void:
	var b := BuildGrid.bounds(pl)
	sitting = {"pl": pl, "back": player.pos}
	player.pos = Vector3((b.minX + b.maxX) / 2.0, pl.y + 0.28, (b.minZ + b.maxZ) / 2.0)
	player.yaw = -int(pl.r) * PI / 2.0; player.sync()
	player_char.play("sit", true)
	toast("Ahh, cozy. Move to stand up.")

func stand_up() -> void:
	if sitting.is_empty(): return
	var back: Vector3 = sitting.back
	sitting = {}
	player.teleport(back.x, back.z)
	player_char.stop_hold()

func _pos_of(it: Dictionary, key: String) -> float:
	var v = it[key]
	return v.call() if v is Callable else v

func find_target():
	var p := player.pos
	var fwd := player.forward()
	var best = null
	var best_score := INF
	for it in interactables:
		if not it.available.call(): continue
		var dx := _pos_of(it, "x") - p.x
		var dz := _pos_of(it, "z") - p.z
		var d := sqrt(dx * dx + dz * dz)
		if d > it.radius + 0.6: continue
		var facing := (dx * fwd.x + dz * fwd.y) / d if d > 0.01 else 1.0
		if d > 1.0 and facing < 0.1: continue
		var score: float = d - facing * 0.8 - it.priority
		if score < best_score: best_score = score; best = it
	return best

func _set_highlight(obj, on: bool) -> void:
	if obj == null or not is_instance_valid(obj): return
	for m in obj.find_children("*", "MeshInstance3D", true, false):
		var mat = m.material_override
		if not mat is StandardMaterial3D: continue
		if on:
			if not m.has_meta("orig_mat"):
				m.set_meta("orig_mat", mat)
				var c: StandardMaterial3D = mat.duplicate()
				c.emission_enabled = true; c.emission = Color("ffd98a"); c.emission_energy_multiplier = 0.35
				m.material_override = c
		elif m.has_meta("orig_mat"):
			m.material_override = m.get_meta("orig_mat"); m.remove_meta("orig_mat")

func _update_interaction() -> void:
	var prev = target
	target = find_target() if mode == "explore" else null
	if prev != null and prev != target: _set_highlight(prev.get("object"), false)
	if target != null:
		_set_highlight(target.get("object"), true)
		prompt_label.text = "[%s]  %s" % [Controls.key_label("interact"), target.label.call()]
		prompt_panel.visible = true
		if Input.is_action_just_pressed("interact"): target.act.call()
	else:
		prompt_panel.visible = false

func _input(event: InputEvent) -> void:
	if mode == "build" and event is InputEventMouseMotion: build.mouse = event.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] or (event.button_index == MOUSE_BUTTON_LEFT and mode == "explore"):
			if event.pressed and not (mode == "build" and event.button_index == MOUSE_BUTTON_LEFT): dragging = true; _drag_dist = 0.0; drag_moved = false
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: cam.zoom(-1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam.zoom(1)
	if event is InputEventMouseMotion and dragging:
		_drag_dist += event.relative.length()
		if _drag_dist > 6.0: drag_moved = true
		if drag_moved: cam.rotate_by(event.relative.x * 0.0055, event.relative.y * 0.0055)
	if mode == "build": build.handle_input(event)
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		dragging = false

func move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return v

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	time += dt
	if Input.is_action_pressed("cam_left"): cam.yaw += 1.8 * dt
	if Input.is_action_pressed("cam_right"): cam.yaw -= 1.8 * dt
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > 0.15: cam.rotate_by(look.x * 2.4 * dt, look.y * 1.6 * dt)
	if mode == "explore":
		if not sitting.is_empty():
			if move_vector().length() > 0.3 or Input.is_action_just_pressed("jump"): stand_up()
			else: player_char.animate(dt)
		else:
			player.update(dt, move_vector(), Input.is_action_pressed("sprint"), Input.is_action_just_pressed("jump"), cam.move_yaw(), true)
		if Input.is_action_just_pressed("build") and build.open(): mode = "build"
	elif mode == "build":
		player_char.animate(dt)
		build.update(dt)
		if not build.active: mode = "explore"
	else:
		player_char.animate(dt)
	cam.update(dt, player.pos)
	for pl in state.placements:
		var n: Node3D = piece_nodes.get(pl.uid)
		if n: PieceMeshes.animate(n, pl, time, dt, {"spinning": mech.powered.has(pl.uid) or mech.sources.has(pl.uid), "powered": mech.powered.has(pl.uid), "watered": mech.watered.has(pl.uid), "on": pl.get("state", {}).get("on", false), "open": pl.get("state", {}).get("open", false), "night": state.flags.get("night", false)})
	_update_interaction()
	hotkeys.text = "%s %s %s %s Move   Drag / %s %s Camera   Wheel Zoom   %s Interact   %s Hop" % [Controls.key_label("move_forward"), Controls.key_label("move_left"), Controls.key_label("move_back"), Controls.key_label("move_right"), Controls.key_label("cam_left"), Controls.key_label("cam_right"), Controls.key_label("interact"), Controls.key_label("jump")]
	var vflags: Dictionary = state.flags.duplicate(); vflags["fountainFlowing"] = mech.fed.get("fountain", false)
	village.update_world(dt, time, vflags)
	sun.position = build.focus if mode == "build" else player.pos
	toasts.offset_top = 160 if mode == "build" else 72
	if mode == "build": hotkeys.get_parent().visible = false
	else: hotkeys.get_parent().visible = true
	_tick_shot()

# ---- Command-line hooks for automated screenshots: godot --path godot -- --shot=out.png --pos=x,z,yaw --cam=yaw,pitch,dist --frames=N
func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		shot_cfg[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if shot_cfg.has("pos"):
		var p: PackedStringArray = String(shot_cfg.pos).split(",")
		player.teleport(float(p[0]), float(p[1]), float(p[2]) if p.size() > 2 else null)
	if shot_cfg.has("cam"):
		var c: PackedStringArray = String(shot_cfg.cam).split(",")
		cam.yaw = float(c[0]); cam.pitch = float(c[1]); cam.dist = float(c[2])
		cam.limits.explore = [2.0, 120.0, 0.05, 1.5]

var _frames := 0
func _tick_shot() -> void:
	if not shot_cfg.has("shot"): return
	_frames += 1
	if _frames == int(shot_cfg.get("frames", "30")):
		get_viewport().get_texture().get_image().save_png(shot_cfg.shot)
		get_tree().quit()
