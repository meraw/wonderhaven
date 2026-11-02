class_name DialogueUI
extends Control
## Dialogue box: name plate, live 3D portrait, typewriter text and choices (mouse, keys 1-9, arrows + E, gamepad).

signal lines_finished
signal chose(option: Dictionary)

var game
var npc
var open := false
var queue: Array = []
var qi := -1
var full := ""
var shown := 0.0
var typing := false
var choices: Array = []
var focus_index := 0
var name_label: Label
var hearts_label: Label
var text_label: Label
var choice_box: VBoxContainer
var more_label: Label
var portrait_vp: SubViewport
var portrait_cam: Camera3D

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE; visible = false
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14)
	row.anchor_left = 0.5; row.anchor_right = 0.5; row.anchor_top = 1; row.anchor_bottom = 1
	row.offset_left = -450; row.offset_right = 450; row.offset_top = -230; row.offset_bottom = -20
	row.alignment = BoxContainer.ALIGNMENT_END
	add_child(row)
	var frame := UiTheme.panel(Color("ffefd2"), UiTheme.LINE, 26)
	frame.custom_minimum_size = Vector2(176, 176); frame.size_flags_vertical = Control.SIZE_SHRINK_END
	var svc := SubViewportContainer.new(); svc.stretch = true; svc.custom_minimum_size = Vector2(160, 160)
	portrait_vp = SubViewport.new(); portrait_vp.size = Vector2i(320, 320); portrait_vp.own_world_3d = false; portrait_vp.transparent_bg = false
	portrait_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portrait_cam = Camera3D.new(); portrait_cam.fov = 30; portrait_cam.cull_mask = 1; portrait_vp.add_child(portrait_cam)
	svc.add_child(portrait_vp); frame.add_child(svc); row.add_child(frame)
	var box := UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 26)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.custom_minimum_size = Vector2(0, 170)
	var v := VBoxContainer.new(); box.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	var np := UiTheme.panel(UiTheme.PINK, UiTheme.PINK_DARK, 999)
	name_label = UiTheme.label("", 17, Color.WHITE); np.add_child(name_label); head.add_child(np)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	hearts_label = UiTheme.label("", 14, Color("ff6f91")); head.add_child(hearts_label)
	text_label = UiTheme.label("", 19); text_label.autowrap_mode = TextServer.AUTOWRAP_WORD; text_label.custom_minimum_size = Vector2(560, 56); v.add_child(text_label)
	choice_box = VBoxContainer.new(); v.add_child(choice_box)
	more_label = UiTheme.label("▼ click / E", 13, UiTheme.INK2); more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; v.add_child(more_label)
	box.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: advance())
	row.add_child(box)

func start(agent) -> void:
	npc = agent; open = true; visible = true
	portrait_vp.world_3d = game.get_viewport().world_3d
	name_label.text = npc.def.name
	update_hearts()

func update_hearts() -> void:
	var h := int(game.state.relationships.get(npc.def.id, {}).get("hearts", 0))
	hearts_label.text = "♥".repeat(mini(10, h)) + "♡".repeat(maxi(0, 5 - h))

## Shows lines one after another; await the returned signal. A line may be a String or {text, mood, anim, player}.
func say(lines: Array, opts: Dictionary = {}) -> void:
	queue = lines.map(func(l): return l if l is Dictionary else {"text": l})
	qi = -1
	set_meta("opts", opts)
	_next_line()
	if not queue.is_empty() or typing: await lines_finished

func _next_line() -> void:
	qi += 1
	if qi >= queue.size():
		queue = []; npc.character.set_talking(false); lines_finished.emit(); return
	var line: Dictionary = queue[qi]
	var opts: Dictionary = get_meta("opts", {})
	full = line.text; shown = 0.0; typing = true
	text_label.text = ""
	for c in choice_box.get_children(): c.queue_free()
	more_label.visible = false
	var speaker: Chibi = game.player_char if line.get("player", false) else npc.character
	name_label.text = game.state.name if line.get("player", false) else npc.def.name
	npc.character.set_talking(not line.get("player", false))
	if line.has("mood") or opts.has("mood"): speaker.set_mood(line.get("mood", opts.get("mood", "")), 2.5)
	if line.has("anim") or (qi == 0 and opts.has("anim")): speaker.play(line.get("anim", opts.get("anim", "")))
	game.voice(1.0 if line.get("player", false) else npc.def.get("voice", 1.0), mini(6, int(ceil(full.length() / 14.0))))

func advance() -> void:
	if not choices.is_empty() or queue.is_empty(): return
	if typing: shown = full.length(); return
	game.sfx("blip")
	_next_line()

func choose(options: Array) -> Dictionary:
	choices = options; focus_index = 0
	for c in choice_box.get_children(): c.queue_free()
	more_label.visible = false
	for n in options.size():
		var o: Dictionary = options[n]
		var b := Button.new(); b.text = "%d. %s" % [n + 1, o.label]; b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.name = "choice_%d" % n
		if o.get("quest", false): b.add_theme_stylebox_override("normal", UiTheme.box(Color("fff7cf"), UiTheme.GOLD, 14, 3, 6, false))
		var idx := n
		b.pressed.connect(func(): pick(idx))
		choice_box.add_child(b)
	_highlight()
	var res = await chose
	return res

func pick(n: int) -> void:
	if choices.is_empty(): return
	var o: Dictionary = choices[n]
	choices = []
	for c in choice_box.get_children(): c.queue_free()
	game.sfx("select")
	chose.emit(o)

func _highlight() -> void:
	for n in choice_box.get_child_count():
		var b: Button = choice_box.get_child(n)
		b.add_theme_color_override("font_color", UiTheme.PINK_DARK if n == focus_index else UiTheme.INK)

func set_text(t: String) -> void:
	text_label.text = t; full = t; typing = false
	for c in choice_box.get_children(): c.queue_free()
	more_label.visible = false

func update(dt: float) -> void:
	if not open: return
	if typing:
		shown = minf(full.length(), shown + dt * 48.0)
		text_label.text = full.substr(0, int(shown))
		if shown >= full.length(): typing = false; npc.character.set_talking(false); more_label.visible = choices.is_empty()
	if not choices.is_empty():
		if Input.is_action_just_pressed("move_back") or Input.is_action_just_pressed("ui_down"): focus_index = (focus_index + 1) % choices.size(); _highlight()
		if Input.is_action_just_pressed("move_forward") or Input.is_action_just_pressed("ui_up"): focus_index = (focus_index + choices.size() - 1) % choices.size(); _highlight()
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"): pick(focus_index)
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"): advance()
	# Portrait camera looks at the speaker's face
	var head: Vector3 = npc.character.head_world_pos()
	var y: float = npc.character.rotation.y
	portrait_cam.global_position = head + Vector3(sin(y) * 2.3, 0.05, cos(y) * 2.3)
	portrait_cam.look_at(head - Vector3(0, 0.08, 0), Vector3.UP)

func _input(event: InputEvent) -> void:
	if not open or choices.is_empty(): return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var n := code - KEY_1
		if n >= 0 and n < mini(9, choices.size()):
			get_viewport().set_input_as_handled()
			pick(n)

func end() -> void:
	open = false; visible = false; queue = []; choices = []
	if npc: npc.character.set_talking(false)
