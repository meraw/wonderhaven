extends Control
## Title screen, character creator (new game) and wardrobe (change your look later; locked pieces unlock in play).

var game
var t := 0.0
var draft := {}
var wardrobe_mode := false
var spin := 0.4
var saved_yaw := 0.0
var dragging := false
var guided := true   # creator checkbox: start with the guided first day

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE; visible = false

func _clear() -> void:
	for c in get_children(): c.queue_free()

func title() -> void:
	game.set_mode("title"); game.hud.visible = false; game.player_char.visible = false; game.hud.clear_tips()
	_clear(); visible = true; mouse_filter = Control.MOUSE_FILTER_STOP
	# A soft vignette keeps the village vivid in the middle while the edges settle back behind the menu.
	var vg := GradientTexture2D.new(); vg.fill = GradientTexture2D.FILL_RADIAL; vg.fill_from = Vector2(0.5, 0.45); vg.fill_to = Vector2(1.1, 1.1)
	var gr := Gradient.new(); gr.colors = PackedColorArray([Color(0.35, 0.2, 0.35, 0.0), Color(0.35, 0.2, 0.35, 0.0), Color(0.25, 0.12, 0.3, 0.45)]); gr.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	vg.gradient = gr
	var bg := TextureRect.new(); bg.texture = vg; bg.stretch_mode = TextureRect.STRETCH_SCALE; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
	var v := VBoxContainer.new(); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 14); add_child(v)
	var l1 := UiTheme.label("Wonderhaven", 88, Color.WHITE); l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.add_theme_color_override("font_outline_color", UiTheme.PINK_DARK); l1.add_theme_constant_override("outline_size", 24)
	l1.add_theme_color_override("font_shadow_color", Color(0.45, 0.15, 0.3, 0.45)); l1.add_theme_constant_override("shadow_offset_y", 7); l1.add_theme_constant_override("shadow_outline_size", 24)
	v.add_child(l1)
	var sub := UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 999); sub.add_child(UiTheme.label("✦ The Lost Isles ✦", 26))
	var sc := CenterContainer.new(); sc.add_child(sub); v.add_child(sc)
	var bb := VBoxContainer.new(); bb.custom_minimum_size.x = 280; bb.add_theme_constant_override("separation", 10)
	var bc := CenterContainer.new(); bc.add_child(bb); v.add_child(bc)
	var latest := SaveSystem.latest()
	if latest != "": var b := UiTheme.button("▶ Continue", func(): continue_from(latest), true); b.name = "btn_continue"; bb.add_child(b)
	var nb := UiTheme.button("✨ New Game", creator, latest == ""); nb.name = "btn_new"; bb.add_child(nb)
	if latest != "": var lb := UiTheme.button("📂 Load Game", load_list); lb.name = "btn_load"; bb.add_child(lb)
	bb.add_child(UiTheme.button("⚙️ Settings", func(): game.panels.settings()))
	for b in bb.get_children(): b.custom_minimum_size.y = 46; b.add_theme_font_size_override("font_size", 19)
	var fp := UiTheme.panel(Color(UiTheme.CREAM, 0.85), Color(UiTheme.LINE, 0.8), 999)
	fp.add_child(UiTheme.label("A cozy kingdom-building adventure · Chapter 1: Hearthglow Village", 14, UiTheme.INK2))
	var fc := CenterContainer.new(); fc.add_child(fp); v.add_child(fc)

func load_list() -> void:
	_clear()
	var p := UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 26)
	p.anchor_left = 0.5; p.anchor_right = 0.5; p.anchor_top = 0.5; p.anchor_bottom = 0.5; p.offset_left = -280; p.offset_right = 280; p.offset_top = -200; p.offset_bottom = 200
	var v := VBoxContainer.new(); p.add_child(v); add_child(p)
	v.add_child(UiTheme.label("📂 Load Game", 24))
	for slot in [SaveSystem.AUTOSAVE] + SaveSystem.SLOTS:
		var m := SaveSystem.meta(slot)
		if m.is_empty(): continue
		var row := HBoxContainer.new(); v.add_child(row)
		var l := UiTheme.label(("Autosave" if slot == SaveSystem.AUTOSAVE else "Slot " + slot.right(1)) + "  —  " + ("Damaged" if m.get("broken", false) else "%s · Day %d · 💖 %d" % [m.name, m.day, m.harmony]), 15); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		var s: String = slot
		var b := UiTheme.button("Load", func(): continue_from(s), true); b.name = "load_" + slot; b.disabled = m.get("broken", false); row.add_child(b)
	v.add_child(UiTheme.button("← Back", title))

func continue_from(slot: String) -> void:
	var s := SaveSystem.read(slot)
	if s.is_empty(): game.toast("That save could not be read", "warn"); return
	_close()
	game.player_char.visible = true
	game.load_state(s)
	game.begin_play()
	game.banner("Welcome back, %s!" % s.name, "Day %d in Hearthglow" % int(s.time.day))

func _close() -> void:
	_clear(); visible = false; mouse_filter = Control.MOUSE_FILTER_IGNORE

func creator(wardrobe: bool = false) -> void:
	wardrobe_mode = wardrobe
	var A: Dictionary = Data.appearance
	var base: Dictionary = game.state.appearance.duplicate()
	if not wardrobe:
		base.hair = A.HAIR_STYLES[randi() % 6]; base.hairColor = A.HAIR_COLORS[randi() % A.HAIR_COLORS.size()]; base.topColor = A.CLOTH_COLORS[randi() % A.CLOTH_COLORS.size()]
	draft = {"name": game.state.name if wardrobe else "Apprentice", "appearance": Chibi.sanitize(base)}
	game.set_mode("creator"); game.hud.visible = false
	game.player_char.visible = true
	if not wardrobe: game.player.teleport(0, 9.5, 0.0)
	saved_yaw = game.player.yaw; spin = 0.4
	game.player_char.set_appearance(draft.appearance)
	visible = true; mouse_filter = Control.MOUSE_FILTER_STOP
	_render_creator()

func _locked(v: String) -> bool:
	if not wardrobe_mode: return Data.appearance.locked.has(v)
	return not GameState.clothing_unlocked(game.state, v)

func _pick(k: String, v: String) -> void:
	if _locked(v): game.toast("🔒 %s — %s" % [Data.appearance.labels.get(v, v), Data.appearance.locked[v]], "warn", 3.0); return
	draft.appearance[k] = v
	game.player_char.set_appearance(draft.appearance)
	game.player_char.play("wave" if randf() < 0.5 else "nod")
	game.sfx("select")
	_render_creator()

func _render_creator() -> void:
	_clear()
	var A: Dictionary = Data.appearance
	var a: Dictionary = draft.appearance
	var p := UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 28)
	p.anchor_left = 1; p.anchor_right = 1; p.anchor_top = 0; p.anchor_bottom = 1
	p.offset_left = -500; p.offset_right = -30; p.offset_top = 24; p.offset_bottom = -24
	add_child(p)
	var outer := VBoxContainer.new(); p.add_child(outer)
	outer.add_child(UiTheme.label("👗 Wardrobe" if wardrobe_mode else "✨ Create your apprentice", 24))
	var scroll := ScrollContainer.new(); scroll.name = "creator_scroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; outer.add_child(scroll)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 6); scroll.add_child(v)
	if not wardrobe_mode:
		v.add_child(UiTheme.label("Name", 14, UiTheme.INK2))
		var le := LineEdit.new(); le.text = draft.name; le.max_length = 16; le.name = "name_input"; le.text_changed.connect(func(tx): draft.name = tx); v.add_child(le)
	var swatches := func(k: String, colors: Array) -> HFlowContainer:
		var row := HFlowContainer.new()
		for c in colors:
			var col: String = c
			var b := Button.new(); b.custom_minimum_size = Vector2(28, 28); b.name = "sw_%s_%s" % [k, col.substr(1)]
			var sb := UiTheme.box(Color(col), UiTheme.PINK if a[k] == col else Color.WHITE, 999, 4 if a[k] == col else 2, 0, false)
			b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sb); b.add_theme_stylebox_override("pressed", sb)
			b.pressed.connect(func(): _pick(k, col))
			row.add_child(b)
		return row
	var pills := func(k: String, list: Array) -> HFlowContainer:
		var row := HFlowContainer.new()
		for val in list:
			var vv: String = val
			var lk := _locked(vv)
			var b := UiTheme.button(("🔒 " if lk else "") + A.labels.get(vv, vv), func(): _pick(k, vv), a[k] == vv)
			b.name = "opt_%s_%s" % [k, vv]; b.add_theme_font_size_override("font_size", 13)
			if lk: b.modulate = Color(1, 1, 1, 0.55); b.tooltip_text = "Locked: " + A.locked[vv]
			row.add_child(b)
		return row
	for sec in [["Skin tone", null, "skin", A.SKIN_TONES], ["Eyes", ["eyeShape", A.EYE_SHAPES], "eyeColor", A.EYE_COLORS], ["Expression", ["mouth", A.MOUTHS], null, null],
			["Hairstyle", ["hair", A.HAIR_STYLES], "hairColor", A.HAIR_COLORS], ["Top", ["top", A.TOPS], "topColor", A.CLOTH_COLORS], ["Bottoms", ["bottom", A.BOTTOMS], "bottomColor", A.CLOTH_COLORS],
			["Shoes", ["shoes", A.SHOES], "shoesColor", A.CLOTH_COLORS], ["Hat", ["hat", A.HATS], "hatColor", A.CLOTH_COLORS], ["Accessory", ["accessory", A.ACCESSORIES], null, null]]:
		v.add_child(UiTheme.label(sec[0], 14, UiTheme.INK2))
		if sec[1] != null: v.add_child(pills.call(sec[1][0], sec[1][1]))
		if sec[2] != null: v.add_child(swatches.call(sec[2], sec[3]))
	if not wardrobe_mode:
		var gd := CheckBox.new(); gd.name = "guided_toggle"; gd.text = "🧭 Guided first day (recommended)"; gd.button_pressed = guided; gd.tooltip_text = "Odessa shows you around one step at a time."
		gd.toggled.connect(func(v): guided = v); outer.add_child(gd)
	var row := HBoxContainer.new(); outer.add_child(row)
	row.add_child(UiTheme.button("🎲 Surprise me", _randomize))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(sp)
	if wardrobe_mode: row.add_child(UiTheme.button("Cancel", func(): close_wardrobe(false)))
	else: row.add_child(UiTheme.button("← Back", title))
	var go := UiTheme.button("Looks great!" if wardrobe_mode else "Begin adventure ➜", func(): close_wardrobe(true) if wardrobe_mode else start_new_game(), true)
	go.name = "btn_start"; row.add_child(go)
	var hint := UiTheme.label("Drag to turn · locked pieces unlock as you play", 15, Color.WHITE)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35)); hint.add_theme_constant_override("outline_size", 6)
	hint.position = Vector2(30, get_viewport_rect().size.y - 50); add_child(hint)

func _randomize() -> void:
	var A: Dictionary = Data.appearance
	var a: Dictionary = draft.appearance
	var free := func(l: Array) -> Array: return l.filter(func(x): return not _locked(x))
	var pick := func(l: Array): return l[randi() % l.size()]
	a.skin = pick.call(A.SKIN_TONES); a.eyeShape = pick.call(A.EYE_SHAPES); a.eyeColor = pick.call(A.EYE_COLORS); a.mouth = pick.call(A.MOUTHS)
	a.hair = pick.call(A.HAIR_STYLES); a.hairColor = pick.call(A.HAIR_COLORS); a.top = pick.call(free.call(A.TOPS)); a.topColor = pick.call(A.CLOTH_COLORS)
	a.bottom = pick.call(A.BOTTOMS); a.bottomColor = pick.call(A.CLOTH_COLORS); a.shoes = pick.call(A.SHOES); a.shoesColor = pick.call(A.CLOTH_COLORS)
	a.hat = "none" if randf() < 0.5 else pick.call(free.call(A.HATS)); a.hatColor = pick.call(A.CLOTH_COLORS); a.accessory = "none" if randf() < 0.6 else pick.call(free.call(A.ACCESSORIES))
	game.player_char.set_appearance(a); game.player_char.play("celebrate"); game.sfx("sparkle")
	_render_creator()

func close_wardrobe(keep: bool) -> void:
	if keep:
		game.state.appearance = Chibi.sanitize(draft.appearance)
		game.effects.sparkle(game.player.pos + Vector3(0, 1, 0), 24); game.sfx("sparkle"); game.autosave("wardrobe", true)
	game.player_char.set_appearance(game.state.appearance)
	game.player.yaw = saved_yaw; game.player.sync()
	_close(); game.hud.visible = true
	game.set_mode("explore")

func start_new_game() -> void:
	var n := String(draft.name).strip_edges()
	var state := GameState.new_game(n if n != "" else "Apprentice", draft.appearance)
	state.tutorial = Tutorial.new_state(guided)
	_close()
	var sp: Dictionary = Data.layout.spawn
	game.load_state(state)
	game.player.teleport(sp.x - 6, sp.z, sp.yaw)
	game.cam.yaw = sp.yaw + PI; game.cam.snap()
	game.begin_play()
	arrival(state.name)
	if not guided: game.get_tree().create_timer(2.5).timeout.connect(func(): game.toast("Someone is waving at you by the village gate. Walk over with %s%s%s%s and press %s to talk." % [Controls.key_label("move_forward"), Controls.key_label("move_left"), Controls.key_label("move_back"), Controls.key_label("move_right"), Controls.key_label("interact")], "", 6.0))
	game.sfx("morning")

## A storybook card before the first step: who you are and why you've come.
func arrival(player_name: String) -> void:
	_clear(); visible = true; mouse_filter = Control.MOUSE_FILTER_STOP
	game.set_mode("cutscene")
	var dim := ColorRect.new(); dim.color = Color(0.25, 0.15, 0.2, 0.35); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(dim)
	var card := UiTheme.panel(Color("fff8ec"), UiTheme.LINE, 26); card.name = "arrival_card"
	card.anchor_left = 0.5; card.anchor_right = 0.5; card.anchor_top = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -330; card.offset_right = 330; card.offset_top = -210; card.offset_bottom = 210
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); card.add_child(v)
	var t := UiTheme.label("Hearthglow, at last", 32, UiTheme.PINK_DARK); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var body := func(text: String, size: int = 17, col: Color = UiTheme.INK) -> void:
		var l := UiTheme.label(text, size, col); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.custom_minimum_size.x = 600; v.add_child(l)
	body.call("Three days along the coast road, %s, with a rolled-up notice in your pocket from the market board in Saltmere:" % player_name)
	var note := UiTheme.panel(Color("fffdf6"), Color("d9b48a"), 6)
	var nv := VBoxContainer.new(); note.add_child(nv)
	for line in [["BUILDER WANTED", 22, UiTheme.INK], ["Hearthglow Village · a cozy place in need of clever hands", 15, UiTheme.INK2], ["Room and board at the Lantern Inn. Ask for Odessa Quill.", 15, UiTheme.INK2]]:
		var l := UiTheme.label(line[0], line[1], line[2]); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nv.add_child(l)
	var nc := CenterContainer.new(); nc.add_child(note); v.add_child(nc)
	body.call("The village gate is just ahead. Someone is waving.", 16, UiTheme.INK2)
	var go := UiTheme.button("Walk into the village ➜", _arrive, true); go.name = "btn_arrive"; go.custom_minimum_size = Vector2(280, 48)
	var bc := CenterContainer.new(); bc.add_child(go); v.add_child(bc)
	go.grab_focus.call_deferred()

func _arrive() -> void:
	if game.mode != "cutscene": return
	_close()
	game.set_mode("explore")
	game.interact_cooldown = 0.4
	game.banner("Welcome to Hearthglow!", "Odessa is waiting at the gate", [], 3.5)

func _gui_input(ev: InputEvent) -> void:
	if game.mode != "creator": return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT: dragging = ev.pressed
	if ev is InputEventMouseMotion and dragging: spin += ev.relative.x * 0.01

func update(dt: float) -> void:
	t += dt
	var cam: Camera3D = game.camera
	if game.mode == "title":
		var a := t * 0.05
		cam.global_position = Vector3(sin(a) * 34, 17, cos(a) * 34 + 2); cam.look_at(Vector3.ZERO, Vector3.UP)
		for n in game.npcs.values(): n.update(dt)
	elif game.mode == "creator":
		game.player.yaw = spin; game.player.sync()
		game.player_char.animate(dt)
		var p: Vector3 = game.player.pos
		cam.global_position = Vector3(p.x + 0.9, p.y + 1.15, p.z + 3.6)
		cam.look_at(Vector3(p.x + 0.9, p.y + 0.85, p.z), Vector3.UP)
		if wardrobe_mode:
			for n in game.npcs.values(): n.update(dt)
	game.village.update_world(dt, game.time, game.state.flags)
	if game.audio: game.audio.update_music(game, dt)
