class_name Panels
extends Control
## Menu panels: bag, quest journal, Kingdom Harmony, world map, notice board, pause, saves, settings and controls.

var game
var current := ""
var body: VBoxContainer
var capture_action := ""

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); visible = false; mouse_filter = Control.MOUSE_FILTER_STOP

func open_panel(name: String, title: String) -> VBoxContainer:
	for c in get_children(): c.queue_free()
	# Soft blurred backdrop so the open menu reads clearly against the busy world.
	var dim := ColorRect.new(); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new(); sm.shader = _backdrop_shader(); dim.material = sm
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close())
	add_child(dim)
	var p := UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 30)
	var ps: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate(); ps.shadow_size = 18; ps.shadow_offset = Vector2(0, 8); ps.shadow_color = Color(0.3, 0.15, 0.25, 0.3)
	ps.border_width_top = 3; ps.content_margin_top = 14; ps.content_margin_left = 22; ps.content_margin_right = 22
	p.add_theme_stylebox_override("panel", ps)
	p.anchor_left = 0.5; p.anchor_right = 0.5; p.anchor_top = 0.5; p.anchor_bottom = 0.5
	p.offset_left = -450; p.offset_right = 450; p.offset_top = -310; p.offset_bottom = 310
	add_child(p)
	p.pivot_offset = Vector2(450, 310); p.scale = Vector2(0.96, 0.96); p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel(); tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tw.tween_property(p, "modulate:a", 1.0, 0.12)
	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation", 10); p.add_child(outer)
	var head := HBoxContainer.new(); outer.add_child(head)
	var ribbon := UiTheme.panel(UiTheme.PINK, UiTheme.PINK_DARK, 999)
	var rs: StyleBoxFlat = ribbon.get_theme_stylebox("panel").duplicate(); rs.content_margin_left = 20; rs.content_margin_right = 20; rs.content_margin_top = 4; rs.content_margin_bottom = 6
	ribbon.add_theme_stylebox_override("panel", rs)
	var tl := UiTheme.label(title, 26, Color.WHITE); tl.add_theme_color_override("font_shadow_color", Color(0.6, 0.2, 0.35, 0.35)); tl.add_theme_constant_override("shadow_offset_y", 2)
	ribbon.add_child(tl); head.add_child(ribbon)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	var cb := UiTheme.button("✕", close); cb.name = "close"; cb.tooltip_text = "Close (Esc)"; cb.custom_minimum_size = Vector2(44, 44); cb.add_theme_font_size_override("font_size", 20)
	head.add_child(cb)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	current = name; visible = true
	if game.mode != "title": game.set_mode("menu")
	game.sfx("open")
	game.emit_event("panel", {"id": name})
	return body

## A first-time tip shown inside the open panel, at the top, instead of a floating card over it.
func inline_tip(tip: Dictionary) -> void:
	if body == null: return
	var p := UiTheme.panel(Color("fffdf3"), UiTheme.GOLD, 16)
	var v := VBoxContainer.new(); p.add_child(v)
	v.add_child(UiTheme.label("💡 " + String(tip.title), 16))
	for line in tip.lines:
		var l := RichTextLabel.new(); l.bbcode_enabled = true; l.fit_content = true; l.scroll_active = false; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = Tutorial.fill(line, func(a): return "[b][color=#e86f8f]%s[/color][/b]" % Controls.key_label(a))
		l.add_theme_font_size_override("normal_font_size", 14); l.add_theme_font_size_override("bold_font_size", 14); l.add_theme_color_override("default_color", UiTheme.INK2)
		v.add_child(l)
	body.add_child(p); body.move_child(p, 0)

static var _backdrop: Shader
static func _backdrop_shader() -> Shader:
	if _backdrop == null:
		_backdrop = Shader.new()
		_backdrop.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 2.5).rgb;
	c = mix(c, vec3(0.42, 0.3, 0.38), 0.32);
	COLOR = vec4(c, 1.0);
}
"""
	return _backdrop

func close() -> void:
	if current == "": return
	current = ""; visible = false
	for c in get_children(): c.queue_free()
	if game.mode == "menu": game.set_mode("explore")
	game.sfx("close")

func update(_dt: float) -> void:
	if current == "" or capture_action != "": return
	if Input.is_action_just_pressed("pause"): close(); return
	for pair in [["inventory", "inventory"], ["journal", "journal"], ["map", "map"], ["progress", "progress"]]:
		if Input.is_action_just_pressed(pair[0]) and current == pair[1]: close(); return

func _input(event: InputEvent) -> void:
	if capture_action != "" and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		var a := capture_action; capture_action = ""
		if event.physical_keycode != KEY_ESCAPE:
			game.settings.bindings = Controls.rebind(game.settings.bindings, a, event.physical_keycode)
			game.apply_settings()
		settings()

func _card(bg: Color = Color.WHITE) -> VBoxContainer:
	var p := UiTheme.panel(bg, Color("f3dfc0"), 18)
	var v := VBoxContainer.new(); p.add_child(v); body.add_child(p)
	return v

func _wrap(text: String, size: int = 14, color: Color = UiTheme.INK2) -> Label:
	var l := UiTheme.label(text, size, color); l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 780
	return l

func inventory() -> void:
	open_panel("inventory", "🎒 Your Bag")
	var grid := GridContainer.new(); grid.columns = 5; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); body.add_child(grid)
	# Things you have come first; ones not found yet stay faint so the bag doesn't read as a wall of zeros.
	var order: Array = Data.resource_order.filter(func(i): return int(game.state.inventory.get(i, 0)) > 0) + Data.resource_order.filter(func(i): return int(game.state.inventory.get(i, 0)) <= 0)
	for id in order:
		var r: Dictionary = Data.resources[id]
		var p := UiTheme.panel(Color.WHITE, Color("f3dfc0"), 18); p.custom_minimum_size = Vector2(150, 0); p.name = "item_" + id
		if int(game.state.inventory.get(id, 0)) <= 0: p.modulate = Color(1, 1, 1, 0.4)
		var v := VBoxContainer.new(); p.add_child(v)
		for l in [UiTheme.label(r.icon, 30), UiTheme.label(str(int(game.state.inventory.get(id, 0))), 22), UiTheme.label(r.name, 12, UiTheme.INK2)]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l)
		grid.add_child(p)
	var st: Dictionary = game.state.stats
	var owned := 0
	for c in Data.appearance.locked:
		if game.state.clothes_owned.has(c): owned += 1
	body.add_child(UiTheme.label("Collection", 18, UiTheme.INK2))
	body.add_child(_wrap("📐 %d / %d blueprints   👗 %d / %d special outfits   🐟 %d fish   💎 %d treasures   🔨 %d pieces built" % [game.state.blueprints.size(), Data.pieces.size(), owned, Data.appearance.locked.size(), st.fish, st.treasures, st.placed], 15, UiTheme.INK))
	body.add_child(UiTheme.label("Friends", 18, UiTheme.INK2))
	for n in Data.npcs:
		if game.state.relationships.has(n.id):
			body.add_child(UiTheme.label("%s — %s   %s" % [n.name, n.title, "♥".repeat(int(game.state.relationships[n.id].get("hearts", 0)))], 15))

func journal(tab: String = "active") -> void:
	open_panel("journal", "📜 Quest Journal")
	var e: QuestEngine = game.story.engine
	var tabs := HBoxContainer.new(); body.add_child(tabs)
	for pair in [["active", "Active"], ["optional", "Available side quests"], ["done", "Completed"]]:
		var t: String = pair[0]
		var b := UiTheme.button(pair[1], func(): journal(t), tab == t); b.name = "tab_" + t; tabs.add_child(b)
	var qs: Array = []
	match tab:
		"active": qs = e.active()
		"optional": qs = Data.quests.filter(func(q): return not q.get("main", false) and e.can_offer(q.id))
		"done": qs = e.done()
	if qs.is_empty():
		body.add_child(_wrap({"active": "No active quests. Look for villagers with a ! over their heads.", "optional": "No new side quests right now — keep exploring!", "done": "Nothing completed yet. Every journey starts with a single plank."}[tab], 15))
	for q in qs:
		var v := _card(Color("f6fff8") if tab == "done" else Color.WHITE)
		v.add_child(UiTheme.label(("★ Main story · " if q.get("main", false) else "") + "From " + Data.npc(q.giver).name, 12, Color("b34a6a")))
		v.add_child(UiTheme.label(q.title, 18))
		v.add_child(_wrap(q.description))
		if tab == "active":
			var ready := e.is_ready(q.id)
			for o in q.objectives:
				if o.get("final", false) and not ready: continue
				var st := e.objective(q.id, o)
				var txt: String = ("✔ " if st.done else "○ ") + o.text
				if not st.done and st.need > 1: txt += " (%d/%d)" % [int(game.state.harmony) if o.kind == "harmony" else st.have, st.need]
				v.add_child(UiTheme.label(txt, 14, Color("59a86f") if st.done else UiTheme.INK))
			var qid: String = q.id
			v.add_child(UiTheme.button("📍 Tracking" if game.state.tracked == qid else "📍 Track", func(): game.state.tracked = qid; game.hud.render_tracker(); close(); game.toast("Tracking “%s”" % q.title), game.state.tracked == qid))
		if tab == "optional": v.add_child(UiTheme.label("Talk to %s to start." % Data.npc(q.giver).name, 13, Color("b34a6a")))
		v.add_child(UiTheme.label(_rewards_text(q.get("rewards", {})), 13, Color("a07a20")))

func _rewards_text(r: Dictionary) -> String:
	var parts: Array = []
	if r.get("harmony", 0) > 0: parts.append("💖 %d" % int(r.harmony))
	for k in r.get("items", {}): parts.append("%s %d" % [Data.resources[k].icon, int(r.items[k])])
	for b in r.get("blueprints", []): parts.append("📐 " + Data.piece(b).name)
	for c in r.get("clothes", []): parts.append("👗 " + Data.appearance.labels.get(c, c))
	return "Rewards: " + ("  ".join(parts) if not parts.is_empty() else "the villagers' gratitude")

func progress() -> void:
	open_panel("progress", "💖 Kingdom Harmony")
	var h := int(game.state.harmony)
	var nx := Harmony.next_unlock(h)
	body.add_child(UiTheme.label("%d Harmony%s" % [h, ("  ·  Next: %s at %d" % [nx.title, int(nx.at)]) if not nx.is_empty() else "  ·  Every milestone reached!"], 22))
	var bar := ProgressBar.new(); bar.custom_minimum_size = Vector2(780, 20); bar.show_percentage = false; bar.max_value = nx.at if not nx.is_empty() else 1; bar.value = h if not nx.is_empty() else 1; body.add_child(bar)
	body.add_child(_wrap("Harmony grows when you help villagers, finish quests, build something new for the first time and restore the island."))
	for u in Data.harmony_unlocks:
		var got: bool = h >= u.at
		var v := _card(Color("f3fff6") if got else Color.WHITE)
		v.add_child(UiTheme.label(("🌟 " if got else "🔒 ") + u.title + ("   Unlocked" if got else "   %d Harmony" % int(u.at)), 16))
		v.add_child(_wrap(u.desc, 13))

func notice_board() -> void:
	open_panel("board", "📌 Village Notice Board")
	var e: QuestEngine = game.story.engine
	var offers := Data.quests.filter(func(q): return e.can_offer(q.id))
	if offers.is_empty(): body.add_child(_wrap("No new requests posted. Hearthglow is feeling cozy!", 15, UiTheme.INK))
	for q in offers:
		var v := _card()
		v.add_child(UiTheme.label("Posted by " + Data.npc(q.giver).name, 12, Color("b34a6a"))); v.add_child(UiTheme.label(q.title, 17)); v.add_child(_wrap(q.description))
	body.add_child(_wrap("Tips: a gold ! over someone means a request; a green ★ means you can report back. Your tool hums near buried treasure.", 14))

func map(from_boat: bool = false) -> void:
	open_panel("map", "🗺️ Wonderhaven")
	var info := _wrap("Where shall we sail? Pick an island." if from_boat else "Click an island to learn about it.", 15, UiTheme.INK)
	var canvas := MapView.new(); canvas.game = game; canvas.custom_minimum_size = Vector2(800, 430); canvas.name = "map_view"
	canvas.picked.connect(func(isl: Dictionary):
		var revealed: bool = isl.get("built", false) or game.state.flags.get(isl.get("reveal", "-"), false)
		info.text = ("%s — %s" % [isl.name, isl.desc]) if revealed else "An unexplored island. Rumours say: " + isl.desc
		for c in body.get_children():
			if c.name == "sail": c.queue_free()
		if isl.id == "hearthglow": info.text += "  (You are here.)"
		elif not revealed: info.text += "  Open Hearthglow's harbor and repair the dock to start sailing." if not game.state.flags.get("boatReady", false) else "  The Captain hasn't charted a route here yet."
		elif from_boat or game.state.flags.get("boatReady", false):
			var b := UiTheme.button("⛵ Sail to " + isl.name, func(): game.sail_to(isl), true); b.name = "sail"; body.add_child(b)
		game.sfx("select"))
	body.add_child(canvas); body.add_child(info)

func pause() -> void:
	open_panel("pause", "🌟 Paused")
	var v := VBoxContainer.new(); v.custom_minimum_size.x = 300; v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_theme_constant_override("separation", 10); body.add_child(v)
	for pair in [["▶ Resume", close, true], ["💾 Save game", func(): saves("save"), false], ["📂 Load game", func(): saves("load"), false], ["👗 Wardrobe", func(): close(); game.open_wardrobe(), false], ["⚙️ Settings & controls", settings, false], ["🏠 Quit to title", func(): close(); game.to_title(), false]]:
		var b := UiTheme.button(pair[0], pair[1], pair[2]); b.name = "btn_" + str(pair[0]).substr(2).to_lower().replace(" ", "_"); v.add_child(b)

func saves(mode: String) -> void:
	open_panel("saves", "💾 Save Game" if mode == "save" else "📂 Load Game")
	var slots: Array = SaveSystem.SLOTS if mode == "save" else [SaveSystem.AUTOSAVE] + SaveSystem.SLOTS
	for slot in slots:
		var m := SaveSystem.meta(slot)
		var v := _card()
		var row := HBoxContainer.new(); v.add_child(row)
		var desc: String = "Empty" if m.is_empty() else ("Damaged save" if m.get("broken", false) else "%s · Day %d · 💖 %d · %d quests done" % [m.name, m.day, m.harmony, m.quests])
		var l := UiTheme.label(("Autosave" if slot == SaveSystem.AUTOSAVE else "Slot " + slot.right(1)) + "   —   " + desc, 15); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		var s: String = slot
		var b: Button
		if mode == "save": b = UiTheme.button("Overwrite" if not m.is_empty() else "Save here", func(): game.save_to(s); saves("save"), true)
		else:
			b = UiTheme.button("Load", func(): close(); game.load_from(s), true); b.disabled = m.is_empty() or m.get("broken", false)
		b.name = "slot_" + slot; row.add_child(b)
	body.add_child(UiTheme.button("← Back", pause))

func settings() -> void:
	open_panel("settings", "⚙️ Settings")
	var st: Dictionary = game.settings
	for pair in [["🎵 Music volume", "music", 0.0, 1.0], ["🔔 Sound effects", "sfx", 0.0, 1.0], ["🖱️ Camera sensitivity", "sensitivity", 0.3, 2.5]]:
		var row := HBoxContainer.new(); body.add_child(row)
		var l := UiTheme.label(pair[0], 15); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		var sl := HSlider.new(); sl.min_value = pair[2]; sl.max_value = pair[3]; sl.step = 0.05; sl.value = st[pair[1]]; sl.custom_minimum_size.x = 220
		var key: String = pair[1]
		sl.value_changed.connect(func(v): st[key] = v; game.apply_settings())
		row.add_child(sl)
	var toggles := [["↕️ Invert camera Y", "invert_y"], ["🌦️ Weather effects", "weather"]]
	if Outline.supported(): toggles.append(["✏️ Ink outlines", "outlines"])
	for pair in toggles:
		var cb := CheckBox.new(); cb.text = pair[0]; cb.button_pressed = st.get(pair[1], true)
		var key2: String = pair[1]
		cb.toggled.connect(func(v): st[key2] = v; game.apply_settings())
		body.add_child(cb)
	body.add_child(UiTheme.label("Controls — click a key to change it", 18, UiTheme.INK2))
	for a in Controls.DEFAULTS:
		var row := HBoxContainer.new(); body.add_child(row)
		var l := UiTheme.label(Controls.LABELS[a], 14); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		var act: String = a
		var b := UiTheme.button("Press a key…" if capture_action == a else " / ".join(Controls.keys_of(a).map(func(k): return OS.get_keycode_string(k))), func(): capture_action = act; settings())
		row.add_child(b)
	body.add_child(_wrap("Undo / redo in build mode: Ctrl+Z / Ctrl+Y. Gamepad: left stick move · right stick camera · A interact · X build · Y journal · Start menu · Back map.", 13))
	var row2 := HBoxContainer.new(); body.add_child(row2)
	row2.add_child(UiTheme.button("Reset controls", func(): st.bindings = {}; game.apply_settings(); settings()))
	row2.add_child(UiTheme.button("← Back", pause))

class MapView extends Control:
	signal picked(island: Dictionary)
	var game
	func _draw() -> void:
		var s := size / Vector2(800, 500)
		draw_rect(Rect2(Vector2.ZERO, size), Color("7fd0ec"))
		for n in 40:
			var x := float((n * 137) % 780 + 10) * s.x
			var y := float((n * 89) % 480 + 10) * s.y
			draw_arc(Vector2(x + 8, y), 8, PI, TAU, 8, Color("a9e4f5"), 3)
		var hg: Dictionary = Data.islands[0]
		for isl in Data.islands:
			if isl.id == "hearthglow": continue
			var revealed: bool = game.state.flags.get(isl.get("reveal", "-"), false)
			var a := Vector2(hg.x, hg.y) * s
			var b := Vector2(isl.x, isl.y) * s
			var steps := 16
			for k in steps:
				if k % 2 == 1: continue
				draw_line(a.lerp(b, float(k) / steps), a.lerp(b, float(k + 1) / steps), Color(1, 1, 1, 0.95 if revealed else 0.4), 4)
		for isl in Data.islands:
			var revealed: bool = isl.get("built", false) or game.state.flags.get(isl.get("reveal", "-"), false)
			var c := Vector2(isl.x, isl.y) * s
			var r: float = isl.r * s.x
			draw_circle(c + Vector2(0, 8), r + 12, Color("f0dfae"))
			draw_circle(c, r, Color(isl.color) if revealed else Color("b9c4c8"))
			for k in 5: draw_circle(c + Vector2(cos(k * 1.3) * r * 0.5, sin(k * 1.7) * r * 0.35), 7, Color("4fae63") if revealed else Color("9aa5a9"))
			var font := UiTheme.main_font()
			var name: String = isl.name if revealed else "???"
			draw_string_outline(font, c + Vector2(-r, r + 30), name, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 18, 6, Color.WHITE)
			draw_string(font, c + Vector2(-r, r + 30), name, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 18, UiTheme.INK)
			if not revealed: draw_string(font, c + Vector2(-16, 10), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
			if isl.id == "hearthglow":
				draw_string(font, c + Vector2(-r * 0.7, -r * 0.4), "📍", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
				var n: int = game.story.engine.active().size() + Data.quests.filter(func(q): return game.story.engine.can_offer(q.id)).size()
				if n > 0: draw_string(font, c + Vector2(r * 0.5, -r * 0.5), "❗%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiTheme.PINK_DARK)
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var s := size / Vector2(800, 500)
			for isl in Data.islands:
				if ev.position.distance_to(Vector2(isl.x, isl.y) * s) < isl.r * s.x + 10: picked.emit(isl); return
