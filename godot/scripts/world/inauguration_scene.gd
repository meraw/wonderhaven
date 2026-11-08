class_name InaugurationScene
extends Node3D

const RIBBON := Color("e0524f")
const BRASS := Color("e8c25a")
const CONFETTI := [Color("ff8fab"), Color("ffcf5c"), Color("8fd3ff"), Color("9be08f"), Color("c9a8ff")]

var game
var skipping := false
var playing := false
var clock := 0.0
var ui: Control
var caption: PanelContainer
var caption_text: Label
var ribbon: Node3D
var cam_from := Vector3.ZERO
var cam_to := Vector3.ZERO
var look := Vector3.ZERO
var push := 0.0
var held: Array = []
var last := {}

func setup(g) -> void: game = g

func watch() -> bool:
	if not game.settings.get("inaugurations", true): return false
	return not game.shot_cfg.has("autoplay") or String(game.shot_cfg.get("inauguration", "")) == "play"

func due() -> bool:
	return Inauguration.on() and not Inauguration.pending(game.state, game.state.placements).is_empty()

func run() -> void:
	last = {}
	if not due(): return
	var c := Inauguration.cfg()
	var hs := Needs.hangouts()
	var group := Inauguration.subject(Inauguration.pending(game.state, game.state.placements), game.village_score, c)
	var f := Inauguration.facts(group, hs, game.village_score, game.visit_opts, c)
	var g := Inauguration.grade(f, c)
	var speaker = game.npcs.get(Inauguration.speaker())
	var crowd: Array = game.npcs.values().filter(func(a): return a != speaker and a.present)
	var lines := Inauguration.speech(f, hs, c, [randf(), randf(), randf()])
	var fans: Dictionary = Tastes.fans(group) if WorkDay.on(Data.island) else {}
	var reacts := Inauguration.reactions(f, crowd.map(func(a): return String(a.def.id)), c, randf(), fans)
	var st := {}
	if watch() and speaker != null and speaker.present:
		var dyn: Array = game.walk.dynamic
		game.walk.dynamic = []
		st = Inauguration.stage(game.walk, group, crowd.size())
		game.walk.dynamic = dyn
	skipping = false
	if not st.is_empty(): await _play(st, f, lines, reacts, speaker, crowd, g, c)
	_finish(f, g, c, reacts, lines, not st.is_empty())

func _finish(f: Dictionary, g: float, c: Dictionary, reacts: Array, lines: Array, played: bool) -> void:
	var rec := WorkDay.record(game.state)
	rec["opened"] = Inauguration.summary(f, g, c)
	rec["placed"] = []
	Inauguration.remember(game.state, rec.opened)
	for r in reacts:
		if r.heart: game.story.add_hearts(String(r.npc), 1)
		if r.get("taste", false): Tastes.learn(game.state, String(r.npc))
	last = {"what": String(f.what), "place": String(f.place), "hangout": String(f.hangout), "grade": Inauguration.grade_text(g, c), "lines": lines,
		"reactions": reacts, "played": played, "skipped": skipping, "uids": f.uids}
	game.emit_event("inauguration", last)

func _play(st: Dictionary, f: Dictionary, lines: Array, reacts: Array, speaker, crowd: Array, g: float, c: Dictionary) -> void:
	playing = true
	clock = 0.0
	var back := {"x": game.player.pos.x, "z": game.player.pos.z, "yaw": game.player.yaw}
	WorkDay.advance(game.state.time, 1.0e6, WorkDay.def(Data.island))
	game.hud.visible = false
	held = [speaker]
	_place(speaker, st.speaker, float(st.yaw))
	var spots: Array = st.crowd
	for i in mini(crowd.size(), spots.size()):
		_place(crowd[i], spots[i], _yaw_to(spots[i], st.speaker))
		held.append(crowd[i])
	var me: Vector3 = st.player if st.player != Vector3.INF else st.speaker
	game.player.teleport(me.x, me.z, float(st.yaw))
	game.player_char.stop_hold()
	game.player_char.visible = true
	_build_ribbon(st.ribbon, float(st.yaw), float(st.ribbon_w))
	_frame(st)
	_build_ui(c, String(speaker.def.get("name", "")))
	game.emit_event("inauguration_start", {"what": String(f.what), "hangout": String(f.hangout)})
	game._fade(false)
	await _wait(0.8)
	for i in lines.size():
		if skipping: break
		_say(speaker, String(lines[i]))
		if i == lines.size() - 1: game.player_char.play("shrug")
		await _wait(clampf(1.4 + String(lines[i]).length() * 0.045, 2.4, 4.6))
	speaker.character.stop_hold()
	caption.visible = false
	if not skipping: await _cut(st, speaker)
	if not skipping: await _react(reacts, Inauguration.mood(f))
	if not skipping:
		_show_card(g, c)
		await _wait(2.6)
	await game._fade(true).finished
	_clear()
	for a in held:
		a.held = false
		a.stare_mark.visible = false
	held = []
	game.cam.cinema = {}
	game.player.teleport(float(back.x), float(back.z), float(back.yaw))
	game.hud.visible = true
	game.interact_cooldown = 0.4
	playing = false

func _yaw_to(from: Vector3, to: Vector3) -> float: return atan2(to.x - from.x, to.z - from.z)

func _place(a, at: Vector3, yaw: float) -> void:
	if a.visiting(): a.end_visit()
	if a.riding: a._ride(false)
	a.held = true
	a.waypoints = []
	a.talking = false
	a.pos = at
	a.yaw = yaw
	a.character.stop_hold()
	a.stare_mark.visible = false
	a.sync()

func _wait(seconds: float) -> void:
	var tree := get_tree()
	var t := 0.0
	while t < seconds and not skipping:
		await tree.process_frame
		var dt := minf(tree.root.get_process_delta_time(), 0.1)
		t += dt
		clock += dt
		if clock > 0.4 and Input.is_action_just_pressed("pause"): skipping = true
		push = minf(1.0, push + dt / 14.0)
		game.cam.cinema = {"pos": cam_from.lerp(cam_to, smoothstep(0.0, 1.0, push)), "look": look}

func _frame(st: Dictionary) -> void:
	look = st.look
	var pick := Vector3.INF
	var fallback: Vector3 = st.cams[0]
	var best := -1.0
	for cp in st.cams:
		var p: Vector3 = cp
		p.y = maxf(p.y, Heightfield.height(p.x, p.z) + 1.2)
		var v: Vector3 = p - look
		var clear: float = game.cam.clear_distance(look, v.normalized(), v.length())
		var inside: bool = game.walk.blocked(p.x, p.z, Heightfield.height(p.x, p.z), 0.3)
		if clear >= v.length() - 0.01 and not inside and not game.cam.blocked(p, look):
			pick = p
			break
		if clear > best:
			best = clear
			fallback = look + v.normalized() * maxf(clear - 0.3, 1.5)
	if pick == Vector3.INF: pick = fallback
	cam_from = pick
	cam_to = pick.lerp(look, 0.12)
	push = 0.0
	game.cam.cinema = {"pos": cam_from, "look": look}

func _say(speaker, text: String) -> void:
	caption_text.text = text
	caption.visible = true
	speaker.character.play("talk", true)
	game.voice(float(speaker.def.get("voice", 1.0)), clampi(text.split(" ").size() / 2, 2, 8))

func _cut(st: Dictionary, speaker) -> void:
	speaker.yaw = _yaw_to(speaker.pos, st.ribbon)
	speaker.sync()
	speaker.character.play("build")
	await _wait(0.55)
	if skipping: return
	_snip()
	await _wait(0.5)
	speaker.yaw = float(st.yaw)
	speaker.sync()
	speaker.character.play("wave")

func _react(reacts: Array, mood: String) -> void:
	var by := {}
	for a in held: by[String(a.def.id)] = a
	for r in reacts:
		var a = by.get(String(r.npc))
		if a == null: continue
		a.character.play(String(r.anim))
		if String(r.anim) == "shrug": a.stare_mark.visible = true
		if String(r.line) != "": _bubble(a, String(r.line))
		if r.heart: game.effects.hearts(a.pos + Vector3(0, 1.8, 0), 4)
	game.player_char.play("celebrate" if mood != "puzzled" else "shrug")
	if game.audio:
		if mood == "puzzled":
			for i in 3: game.audio.play("chirp", 90, 0.1, -1, 0.4 + i * 0.5)
		else:
			for i in 14: game.audio.play("clap", 58 + randi() % 10, 0.2, -1, randf() * 1.6)
	await _wait(2.4)

func _bubble(a, text: String) -> void:
	var l := Label3D.new()
	l.name = "say"
	l.text = text
	l.font = UiTheme.main_font()
	l.font_size = 34
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = UiTheme.INK
	l.outline_modulate = Color.WHITE
	l.outline_size = 16
	l.position = Vector3(0, 2.3, 0)
	a.character.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(l.queue_free)

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.55
	return m

func _build_ribbon(at: Vector3, yaw: float, w: float) -> void:
	ribbon = Node3D.new()
	ribbon.name = "ribbon"
	add_child(ribbon)
	ribbon.position = Vector3(at.x, float(game.walk.surface_at(at.x, at.z, at.y + 0.3).y), at.z)
	ribbon.rotation.y = yaw
	var brass := _mat(BRASS)
	var red := _mat(RIBBON)
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.045
		cm.height = 1.0
		post.mesh = cm
		post.material_override = brass
		post.position = Vector3(sx * w / 2.0, 0.5, 0.0)
		ribbon.add_child(post)
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		knob.mesh = sm
		knob.material_override = brass
		knob.position = Vector3(sx * w / 2.0, 1.02, 0.0)
		ribbon.add_child(knob)
		var pivot := Node3D.new()
		pivot.name = "half_l" if sx < 0.0 else "half_r"
		pivot.position = Vector3(sx * w / 2.0, 0.9, 0.0)
		ribbon.add_child(pivot)
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w / 2.0, 0.1, 0.015)
		band.mesh = bm
		band.material_override = red
		band.position = Vector3(-sx * w / 4.0, 0.0, 0.0)
		pivot.add_child(band)
	var bow := Node3D.new()
	bow.name = "bow"
	bow.position = Vector3(0.0, 0.9, 0.0)
	ribbon.add_child(bow)
	for sx in [-1.0, 1.0]:
		var loop := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.09
		lm.height = 0.14
		loop.mesh = lm
		loop.material_override = red
		loop.scale = Vector3(1.5, 1.0, 0.5)
		loop.position = Vector3(sx * 0.11, 0.0, 0.0)
		bow.add_child(loop)

func _snip() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ribbon.get_node("half_l"), "rotation:z", -1.45, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(ribbon.get_node("half_r"), "rotation:z", 1.45, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(ribbon.get_node("bow"), "position:y", 0.06, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var top: Vector3 = ribbon.global_position + Vector3(0, 1.2, 0)
	for col in CONFETTI: game.effects.sparkle(top, 10, col, 0.24)
	game.sfx("rustle")
	game.sfx("fanfare")
	game.emit_event("ribbon_cut", {})

func _build_ui(c: Dictionary, who: String) -> void:
	ui = Control.new()
	ui.name = "InaugurationUI"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_root.add_child(ui)
	var strip := CenterContainer.new()
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top = -150
	strip.offset_bottom = -30
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(strip)
	caption = UiTheme.panel(Color(UiTheme.CREAM, 0.96), UiTheme.LINE, 18)
	caption.name = "caption"
	caption.visible = false
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(caption)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	caption.add_child(col)
	col.add_child(UiTheme.label(who, 14, UiTheme.PINK_DARK))
	caption_text = UiTheme.label("", 19)
	caption_text.name = "speech"
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	caption_text.custom_minimum_size.x = 560
	col.add_child(caption_text)
	var skip := UiTheme.button("%s · %s" % [String(c.get("skip", "Skip")), Controls.key_label("pause")], func(): skipping = true)
	skip.name = "inauguration_skip"
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -150
	skip.offset_top = -58
	skip.offset_right = -20
	skip.offset_bottom = -16
	ui.add_child(skip)

func _show_card(g: float, c: Dictionary) -> void:
	var strip := CenterContainer.new()
	strip.name = "card"
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 0.1
	strip.anchor_bottom = 0.1
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(strip)
	var p := UiTheme.panel(Color(UiTheme.CREAM, 0.96), UiTheme.GOLD, 18)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(p)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(col)
	var title := UiTheme.label(String(c.get("card", "Voto {grade}")).replace("{grade}", Inauguration.grade_text(g, c)), 30, UiTheme.PINK_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.name = "grade"
	col.add_child(title)
	var change := int(game.state.harmony) - int(WorkDay.record(game.state).get("harmony", game.state.harmony))
	if change != 0:
		var sub := UiTheme.label("💖 %s%d today" % ["+" if change > 0 else "", change], 16, UiTheme.INK2)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.name = "approval"
		col.add_child(sub)
	p.scale = Vector2(0.6, 0.6)
	p.pivot_offset = p.size / 2.0
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	game.sfx("unlock")

func _clear() -> void:
	if ui:
		game.ui_root.remove_child(ui)
		ui.queue_free()
	ui = null
	if ribbon:
		remove_child(ribbon)
		ribbon.queue_free()
	ribbon = null
	for a in held:
		var say: Node = a.character.get_node_or_null("say")
		if say:
			a.character.remove_child(say)
			say.queue_free()
