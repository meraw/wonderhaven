class_name MinigameUI
extends Control
## The gathering minigames, in a small panel at the right while the camera watches your character work.
## Press = E / Space / click; hold = keep E / Space / mouse button down.

var game
var active := {}
var title: Label
var hint: Label
var result: Label
var body: Control
var dots: HBoxContainer
var result_t := 0.0
var last_results := 0
var bite_played := false
var mouse_press := false
var mouse_hold := false

const TITLES := {"chop": "🪓 Chop the tree!", "mine": "⛏️ Strike the rock!", "fish": "🎣 Fishing"}
const HINTS := {"chop": "Press {interact} (or click) when the needle is in the green. Gold is perfect!", "mine": "Press {interact} when the dark ring lines up with the green circle.", "fish": ""}

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE; visible = false

func start(kind: String, mg) -> void:
	active = {"kind": kind, "mg": mg}
	result_t = 0.0; last_results = 0; bite_played = false
	for c in get_children(): c.queue_free()
	var p := UiTheme.panel(Color(UiTheme.CREAM, 0.94), UiTheme.LINE, 22)
	p.name = "minigame_panel"
	p.anchor_left = 1; p.anchor_right = 1; p.anchor_top = 1; p.anchor_bottom = 1
	p.offset_left = -360; p.offset_right = -20; p.offset_top = -330; p.offset_bottom = -40
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			mouse_hold = ev.pressed
			if ev.pressed: mouse_press = true)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; p.add_child(v)
	title = UiTheme.label(TITLES[kind], 18); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(title)
	body = Control.new(); body.custom_minimum_size = Vector2(300, 120); v.add_child(body)
	var b := body
	body.draw.connect(func(): _draw_body(b))
	dots = HBoxContainer.new(); dots.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(dots)
	if kind != "fish":
		for n in 3: var d := UiTheme.label("●", 18, Color("ecd2a8")); dots.add_child(d)
	hint = UiTheme.label(Tutorial.fill(HINTS[kind], func(a): return Controls.key_label(a)), 13, UiTheme.INK2); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint.autowrap_mode = TextServer.AUTOWRAP_WORD; hint.custom_minimum_size.x = 300; v.add_child(hint)
	result = UiTheme.label("", 20, UiTheme.PINK_DARK); result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(result)
	v.add_child(UiTheme.label("Esc to stop", 11, UiTheme.INK2))
	add_child(p)
	visible = true

func update(dt: float) -> void:
	if active.is_empty(): return
	var mg = active.mg
	if Input.is_action_just_pressed("pause"): _finish(true); return
	var press := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or mouse_press
	var hold := Input.is_action_pressed("interact") or Input.is_action_pressed("jump") or mouse_hold
	mouse_press = false
	if mg.done:
		result_t += dt
		if result_t > 1.1: _finish(false); return
	else:
		mg.step(dt, press, hold)
		if active.kind != "fish" and mg.results.size() > last_results:
			last_results = mg.results.size()
			var r: String = mg.results.back()
			game.sfx("miss" if r == "miss" else ("perfect" if r == "perfect" else "hit"))
			game.player_char.play("mine" if active.kind == "mine" else "chop")
			game.actions.minigame_hit(active.kind, r)
			if r != "miss": game.cam.shake = 0.25
	_render()

func _render() -> void:
	var mg = active.mg
	if active.kind != "fish":
		for n in 3:
			var d: Label = dots.get_child(n)
			var r: String = mg.results[n] if n < mg.results.size() else ""
			d.add_theme_color_override("font_color", {"miss": Color("ffb3b3"), "perfect": Color("ffcf5c"), "good": Color("8fe0b0")}.get(r, Color("ecd2a8")))
	else:
		hint.text = Tutorial.fill({"wait": "Waiting for a bite… (don't pull yet!)", "bite": "❗ A bite! Press {interact}!", "reel": "Hold {interact} to reel — keep the line in the green"}.get(mg.phase, ""), func(a): return Controls.key_label(a))
		hint.add_theme_color_override("font_color", UiTheme.PINK_DARK if mg.phase == "bite" else UiTheme.INK2)
		if mg.phase == "bite" and not bite_played: bite_played = true; game.sfx("bite"); game.player_char.play("surprised")
	if mg.done:
		if active.kind == "fish":
			result.text = {"caught": "Caught %s! 🐟" % Minigames.a_name(mg.fish.name), "snap": "Snap! Too much tension.", "missed": "It got away… press quicker next time!", "early": "Too soon! The fish swam off.", "escaped": "It wriggled free!"}.get(mg.result, "")
		else:
			var hits: int = mg.results.filter(func(r): return r != "miss").size()
			result.text = "%d / 3 hits%s" % [hits, " ✨" if mg.results.has("perfect") else ""]
	body.queue_redraw()

func _draw_body(body: Control) -> void:
	if active.is_empty() or body != self.body: return
	var mg = active.mg
	var w := body.size.x
	if w < 100.0: return
	match active.kind:
		"chop":
			var y := 44.0
			var bw := w - 20
			body.draw_rect(Rect2(10, y, bw, 30), Color("f3e3c8"))
			body.draw_rect(Rect2(10 + (mg.center - mg.width / 2.0) * bw, y, mg.width * bw, 30), Color("8fe0b0"))
			body.draw_rect(Rect2(10 + (mg.center - mg.perfect / 2.0) * bw, y, mg.perfect * bw, 30), Color("ffcf5c"))
			var at: float = mg.hit_at if mg.hit_at >= 0.0 else mg.needle()
			var nc: Color = UiTheme.INK if mg.hit_at < 0.0 else _result_color(mg.last)
			body.draw_rect(Rect2(10 + at * bw - 4, y - 6, 8, 42), nc)
			if mg.pause > 0.0: _flash(body, mg.last, Vector2(10 + at * bw, y - 14))
		"mine":
			# The green band is drawn exactly over the radii that score (draw_arc strokes are centred on the radius).
			var c := Vector2(w / 2.0, 60)
			var k := 70.0
			var t0: float = mg.target[0]; var t1: float = mg.target[1]
			body.draw_arc(c, (t0 + t1) / 2.0 * k, 0, TAU, 64, Color("8fe0b0"), (t1 - t0) * k)
			body.draw_arc(c, (t0 + t1) / 2.0 * k, 0, TAU, 64, Color("ffcf5c"), 0.06 * k)
			var rc: Color = UiTheme.INK if mg.pause <= 0.0 else _result_color(mg.last)
			body.draw_arc(c, maxf(0.02, mg.r) * k, 0, TAU, 64, rc, 4.0)
			if mg.pause > 0.0: _flash(body, mg.last, c + Vector2(0, -k * 0.55 - 6))
		"fish":
			if mg.phase == "reel":
				var x := w / 2.0 - 120
				body.draw_rect(Rect2(x, 5, 30, 110), Color("f3e3c8"))
				body.draw_rect(Rect2(x, 5 + (1.0 - mg.band[1]) * 110, 30, (mg.band[1] - mg.band[0]) * 110), Color("8fe0b0"))
				body.draw_rect(Rect2(x - 4, 5 + (1.0 - mg.tension) * 110 - 4, 38, 8), UiTheme.INK)
				body.draw_rect(Rect2(x + 70, 50, 180, 24), Color("f3e3c8"))
				body.draw_rect(Rect2(x + 70, 50, 180 * minf(1.0, mg.progress), 24), Color("8fe0b0"))
				body.draw_string(UiTheme.main_font(), Vector2(x + 70, 40), "Catch", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.INK2)
			elif mg.phase == "bite":
				body.draw_string(UiTheme.main_font(), Vector2(w / 2.0 - 20, 80), "❗", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, UiTheme.PINK_DARK)

func _result_color(r: String) -> Color:
	return {"perfect": Color("e0a400"), "good": Color("2f9a5c"), "miss": Color("d0505a")}.get(r, UiTheme.INK)

func _flash(body: Control, r: String, at: Vector2) -> void:
	var txt: String = {"perfect": "Perfect!", "good": "Good!", "miss": "Miss"}.get(r, "")
	var f := UiTheme.title_font()
	var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	body.draw_string_outline(f, at - Vector2(sz.x / 2.0, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color.WHITE)
	body.draw_string(f, at - Vector2(sz.x / 2.0, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, _result_color(r))

func _finish(cancelled: bool) -> void:
	var a := active
	active = {}; visible = false; mouse_hold = false
	game.minigame_done(a.kind, null if cancelled else a.mg)
