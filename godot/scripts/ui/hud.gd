class_name Hud
extends Control
## Heads-up display: Harmony bar and clock, quest tracker, compass arrow to the next objective.

var game
var harmony_bar: ProgressBar
var harmony_label: Label
var clock_label: Label
var tracker: VBoxContainer
var compass: Label

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UiTheme.panel(); top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := HBoxContainer.new(); tr.add_theme_constant_override("separation", 10); top.add_child(tr)
	tr.add_child(UiTheme.label("💖 Harmony", 15))
	harmony_bar = ProgressBar.new(); harmony_bar.custom_minimum_size = Vector2(160, 14); harmony_bar.show_percentage = false; harmony_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(harmony_bar)
	harmony_label = UiTheme.label("0", 15); tr.add_child(harmony_label)
	clock_label = UiTheme.label("", 14, UiTheme.INK2); tr.add_child(clock_label)
	var tc := CenterContainer.new(); tc.anchor_right = 1; tc.offset_top = 14; tc.offset_bottom = 54; tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(top); add_child(tc)
	tracker = VBoxContainer.new(); tracker.anchor_left = 1; tracker.anchor_right = 1; tracker.offset_left = -304; tracker.offset_right = -14; tracker.offset_top = 14
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(tracker)
	compass = UiTheme.label("➤", 30, UiTheme.PINK_DARK); compass.pivot_offset = Vector2(15, 20); add_child(compass)

func render_harmony() -> void:
	var h := int(game.state.harmony)
	var nx := Harmony.next_unlock(h)
	harmony_bar.max_value = nx.at if not nx.is_empty() else maxf(h, 1)
	harmony_bar.value = h
	harmony_label.text = ("%d / %d" % [h, int(nx.at)]) if not nx.is_empty() else str(h)

func render_tracker() -> void:
	for c in tracker.get_children(): c.queue_free()
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
