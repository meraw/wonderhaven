class_name Hud
extends Control
## Heads-up display: Harmony bar and clock, quest tracker, compass arrow to the next objective.

var game
var harmony_bar: ProgressBar
var harmony_label: Label
var clock_label: Label
var tracker: VBoxContainer
var compass: Label
var harmony_box: HBoxContainer
var guide_card: PanelContainer
var guide_text: RichTextLabel
var guide_count: Label
var tip_card: PanelContainer
var tip_queue: Array = []
var tip_t := 0.0

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UiTheme.panel(); top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := HBoxContainer.new(); tr.add_theme_constant_override("separation", 10); top.add_child(tr)
	harmony_box = HBoxContainer.new(); harmony_box.add_theme_constant_override("separation", 10); tr.add_child(harmony_box)
	harmony_box.add_child(UiTheme.label("💖 Harmony", 15))
	harmony_bar = ProgressBar.new(); harmony_bar.custom_minimum_size = Vector2(160, 14); harmony_bar.show_percentage = false; harmony_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	harmony_box.add_child(harmony_bar)
	harmony_label = UiTheme.label("0", 15); harmony_box.add_child(harmony_label)
	clock_label = UiTheme.label("", 14, UiTheme.INK2); tr.add_child(clock_label)
	var tc := CenterContainer.new(); tc.anchor_right = 1; tc.offset_top = 14; tc.offset_bottom = 54; tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(top); add_child(tc)
	tracker = VBoxContainer.new(); tracker.anchor_left = 1; tracker.anchor_right = 1; tracker.offset_left = -304; tracker.offset_right = -14; tracker.offset_top = 14
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(tracker)
	compass = UiTheme.label("➤", 30, UiTheme.PINK_DARK); compass.pivot_offset = Vector2(15, 20); add_child(compass)
	_build_guide()

# ---- Guided first day ---------------------------------------------------------------------------------
func _build_guide() -> void:
	guide_card = UiTheme.panel(Color("fffaf0"), UiTheme.PINK, 20); guide_card.name = "guide_card"
	guide_card.position = Vector2(14, 70); guide_card.custom_minimum_size.x = 340
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); guide_card.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	var t := UiTheme.label("🧭 Getting started", 14, UiTheme.PINK_DARK); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	guide_count = UiTheme.label("", 13, UiTheme.INK2); head.add_child(guide_count)
	var skip := LinkButton.new(); skip.text = "skip"; skip.name = "guide_skip"; skip.add_theme_color_override("font_color", UiTheme.INK2); skip.add_theme_font_size_override("font_size", 13)
	skip.pressed.connect(func(): game.guide.skip()); head.add_child(skip)
	guide_text = RichTextLabel.new(); guide_text.bbcode_enabled = true; guide_text.fit_content = true; guide_text.scroll_active = false
	guide_text.custom_minimum_size = Vector2(340, 0); guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; guide_text.name = "guide_text"
	guide_text.add_theme_font_size_override("normal_font_size", 16); guide_text.add_theme_font_size_override("bold_font_size", 16)
	guide_text.add_theme_color_override("default_color", UiTheme.INK); guide_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(guide_text)
	guide_card.visible = false; add_child(guide_card)
	tip_card = UiTheme.panel(Color("fffdf3"), UiTheme.GOLD, 22); tip_card.name = "tip_card"
	tip_card.anchor_top = 0.5; tip_card.anchor_bottom = 0.5; tip_card.offset_left = 14; tip_card.offset_top = -170   # left side, clear of the build catalog and dialogue box
	tip_card.custom_minimum_size.x = 360; tip_card.visible = false
	get_parent().add_child.call_deferred(tip_card)   # above the HUD so it shows in every mode

func _key(action: String) -> String: return "[b][color=#e86f8f]%s[/color][/b]" % Controls.key_label(action)

## Shows the current guided step (or hides the card once the guided day is over).
func render_guide(pop: bool = false) -> void:
	var t: Dictionary = game.state.get("tutorial", {})
	var st := Tutorial.current(t)
	if st.is_empty(): guide_card.visible = false; return
	var text := Tutorial.fill(st.text, _key)
	var done: String = st.get("done", "")
	if done.begins_with("objective:"):
		var parts := done.split(":")
		var q := Data.quest(parts[1])
		var o: Dictionary = q.objectives[int(parts[2])]
		var ob: Dictionary = game.story.engine.objective(parts[1], o)
		if ob.need > 1: text += "  [color=#8a6a50](%d/%d)[/color]" % [ob.have, ob.need]
	guide_text.text = text
	guide_count.text = "%d / %d " % [int(t.step) + 1, Tutorial.steps().size()]
	if pop:
		guide_card.pivot_offset = Vector2(0, 30)
		var tw := guide_card.create_tween(); tw.tween_property(guide_card, "scale", Vector2(1.06, 1.06), 0.1); tw.tween_property(guide_card, "scale", Vector2.ONE, 0.2)

## Hides HUD parts the guided day hasn't introduced yet.
func apply_reveals() -> void:
	var t: Dictionary = game.state.get("tutorial", {})
	harmony_box.visible = Tutorial.revealed(t, "harmony")
	if game.hud_res: game.hud_res.get_parent().visible = Tutorial.revealed(t, "resources")
	render_tracker()

func clear_tips() -> void:
	tip_queue.clear(); tip_card.visible = false
	for c in tip_card.get_children(): c.queue_free()

func show_tip(tip: Dictionary) -> void:
	tip_queue.append(tip)
	if not tip_card.visible: _next_tip()

func _next_tip() -> void:
	for c in tip_card.get_children(): c.queue_free()
	if tip_queue.is_empty(): tip_card.visible = false; return
	var tip: Dictionary = tip_queue.pop_front()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); tip_card.add_child(v)
	v.add_child(UiTheme.label("💡 " + String(tip.title), 20, UiTheme.INK))
	for line in tip.lines:
		var l := RichTextLabel.new(); l.bbcode_enabled = true; l.fit_content = true; l.scroll_active = false; l.custom_minimum_size.x = 340
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.text = Tutorial.fill(line, _key); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("normal_font_size", 15); l.add_theme_font_size_override("bold_font_size", 15); l.add_theme_color_override("default_color", UiTheme.INK2)
		v.add_child(l)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END; v.add_child(row)
	var ok := UiTheme.button("Got it", _next_tip, true); ok.name = "tip_ok"; row.add_child(ok)
	tip_card.visible = true; tip_t = 18.0
	tip_card.modulate.a = 0.0
	var tw := tip_card.create_tween(); tw.tween_property(tip_card, "modulate:a", 1.0, 0.25)
	game.sfx("blip")

## Per frame: guide card only in free play, tip cards fade out on their own after a while.
func tick(dt: float) -> void:
	guide_card.visible = Tutorial.current(game.state.get("tutorial", {})).size() > 0 and game.mode in ["explore", "build"]
	if guide_card.visible and Engine.get_process_frames() % 20 == 0: render_guide()
	if game.mode in ["title", "creator"] and tip_card.visible: clear_tips()
	if tip_card.visible:
		tip_t -= dt
		if tip_t <= 0.0: _next_tip()

func render_harmony() -> void:
	var h := int(game.state.harmony)
	var nx := Harmony.next_unlock(h)
	harmony_bar.max_value = nx.at if not nx.is_empty() else maxf(h, 1)
	harmony_bar.value = h
	harmony_label.text = ("%d / %d" % [h, int(nx.at)]) if not nx.is_empty() else str(h)

func render_tracker() -> void:
	for c in tracker.get_children(): c.queue_free()
	if not Tutorial.revealed(game.state.get("tutorial", {}), "quests"): return
	var e: QuestEngine = game.story.engine
	var act := e.active()
	var tracked = null
	for q in act:
		if q.id == game.state.tracked: tracked = q
	if tracked == null and not act.is_empty(): tracked = act[0]
	var show: Array = []
	if tracked != null:
		show.append(tracked)
		for q in act:
			if q != tracked and q.get("main", false) and show.size() < 2: show.append(q)
	for q in show:
		var ready := e.is_ready(q.id)
		var p := UiTheme.panel(); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new(); p.add_child(v)
		v.add_child(UiTheme.label(("📍 " if q == tracked else "📜 ") + q.title + ("   · Story" if q.get("main", false) else ""), 15))
		for o in q.objectives:
			if o.get("final", false) and not ready: continue
			var st := e.objective(q.id, o)
			if q != tracked and st.done: continue
			var txt: String = ("✔ " if st.done else "○ ") + o.text
			if st.need > 1 and not st.done: txt += " (%d/%d)" % [int(game.state.harmony) if o.kind == "harmony" else st.have, st.need]
			var l := UiTheme.label(txt, 13, Color("59a86f") if st.done else UiTheme.INK2); l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 260
			v.add_child(l)
		tracker.add_child(p)
	if show.is_empty():
		for q in Data.quests:
			if q.get("main", false) and e.can_offer(q.id):
				var p := UiTheme.panel(); var l := UiTheme.label("✨ Next: look for the gold ! — %s needs help" % Data.npc(q.giver).name, 13); l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 260; p.add_child(l); tracker.add_child(p)
				break

func update_compass(target: Dictionary) -> void:
	if target.is_empty() or game.mode != "explore": compass.visible = false; return
	var pp: Vector3 = game.player.pos
	if Vector2(target.x - pp.x, target.z - pp.z).length() < 3.0: compass.visible = false; return
	var world := Vector3(target.x, maxf(0.0, Heightfield.height(target.x, target.z)) + 2.4, target.z)
	var cam: Camera3D = game.camera
	var vs := get_viewport_rect().size
	var behind := cam.is_position_behind(world)
	var p := cam.unproject_position(world)
	var on := not behind and p.x > 40 and p.x < vs.x - 40 and p.y > 90 and p.y < vs.y - 120
	compass.visible = true
	compass.tooltip_text = target.get("label", "")
	if on:
		compass.text = "⭐"; compass.rotation = 0.0; compass.position = p - Vector2(15, 20)
	else:
		if behind: p = vs - p
		var c := vs / 2.0
		var ang := (p - c).angle()
		var r := Vector2(vs.x / 2.0 - 50, vs.y / 2.0 - 110)
		var k := minf(r.x / maxf(0.001, absf(cos(ang))), r.y / maxf(0.001, absf(sin(ang))))
		compass.text = "➤"; compass.rotation = ang; compass.position = c + Vector2(cos(ang), sin(ang)) * k - Vector2(15, 20)
