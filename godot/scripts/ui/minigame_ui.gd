class_name MinigameUI
extends Control
## Overlays for the gathering minigames. Press = E / Space / click; hold = keep E / Space / mouse button down.

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
const HINTS := {"chop": "Press E (or click) when the needle is in the green. Gold is perfect!", "mine": "Press E when the dark ring lines up with the green circle.", "fish": ""}

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE; visible = false

func start(kind: String, mg) -> void:
	active = {"kind": kind, "mg": mg}
	result_t = 0.0; last_results = 0; bite_played = false
	for c in get_children(): c.queue_free()
	var p := UiTheme.panel(UiTheme.CREAM, UiTheme.LINE, 26)
	p.anchor_left = 0.5; p.anchor_right = 0.5; p.anchor_top = 1; p.anchor_bottom = 1
	p.offset_left = -220; p.offset_right = 220; p.offset_top = -380; p.offset_bottom = -150
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			mouse_hold = ev.pressed
			if ev.pressed: mouse_press = true)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; p.add_child(v)
	title = UiTheme.label(TITLES[kind], 20); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(title)
	body = Control.new(); body.custom_minimum_size = Vector2(400, 120); v.add_child(body)
	var b := body
	body.draw.connect(func(): _draw_body(b))
	dots = HBoxContainer.new(); dots.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(dots)
	if kind != "fish":
		for n in 3: var d := UiTheme.label("●", 18, Color("ecd2a8")); dots.add_child(d)
	hint = UiTheme.label(HINTS[kind], 13, UiTheme.INK2); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint.autowrap_mode = TextServer.AUTOWRAP_WORD; v.add_child(hint)
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
		hint.text = {"wait": "Waiting for a bite… (don't pull yet!)", "bite": "❗ A bite! Press E!", "reel": "Hold E to reel — keep the line in the green"}.get(mg.phase, "")
		hint.add_theme_color_override("font_color", UiTheme.PINK_DARK if mg.phase == "bite" else UiTheme.INK2)
		if mg.phase == "bite" and not bite_played: bite_played = true; game.sfx("bite"); game.player_char.play("surprised")
	if mg.done:
		if active.kind == "fish":
			result.text = {"caught": "Caught a %s! 🐟" % mg.fish.name, "snap": "Snap! Too much tension.", "missed": "It got away… press quicker next time!", "early": "Too soon! The fish swam off.", "escaped": "It wriggled free!"}.get(mg.result, "")
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
			body.draw_rect(Rect2(10, y, w - 20, 30), Color("f3e3c8"))
			body.draw_rect(Rect2(10 + (mg.center - mg.width / 2.0) * (w - 20), y, mg.width * (w - 20), 30), Color("8fe0b0"))
			body.draw_rect(Rect2(10 + (mg.center - mg.perfect / 2.0) * (w - 20), y, mg.perfect * (w - 20), 30), Color("ffcf5c"))
			body.draw_rect(Rect2(10 + mg.needle() * (w - 20) - 4, y - 6, 8, 42), UiTheme.INK)
		"mine":
			var c := Vector2(w / 2.0, 60)
			body.draw_arc(c, mg.target[1] * 70.0, 0, TAU, 48, Color("8fe0b0"), (mg.target[1] - mg.target[0]) * 70.0)
			body.draw_arc(c, maxf(0.02, mg.r) * 70.0, 0, TAU, 48, UiTheme.INK, 4.0)
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

func _finish(cancelled: bool) -> void:
	var a := active
	active = {}; visible = false; mouse_hold = false
	game.minigame_done(a.kind, null if cancelled else a.mg)
