class_name Journey
extends CanvasLayer

signal done

const FADE := 0.45
const RIDE := 3.2
const HOLD := 0.5

var view: Panels.MapView
var card: Control
var title: Label
var t := 0.0
var skipping := false
var over := false

static func vehicle(_from_id: String, _to_id: String) -> String: return "🚌"

static func caption(from_id: String, to_id: String) -> String:
	return "%s  →  %s" % [String(Data.island_def(from_id).get("name", from_id)), String(Data.island_def(to_id).get("name", to_id))]

static func progress(seconds: float) -> float:
	return clampf((seconds - FADE) / RIDE, 0.0, 1.0)

static func alpha(seconds: float) -> float:
	var end := FADE + RIDE + HOLD
	if seconds < FADE: return seconds / FADE
	if seconds > end: return clampf(1.0 - (seconds - end) / FADE, 0.0, 1.0)
	return 1.0

static func length() -> float: return FADE * 2.0 + RIDE + HOLD

func setup(game, from_id: String, to_id: String) -> void:
	layer = 110
	name = "Journey"
	card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.modulate.a = 0.0
	add_child(card)
	var bg := ColorRect.new()
	bg.color = Color("fff7ec")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(middle)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	middle.add_child(box)
	title = UiTheme.label(caption(from_id, to_id), 26, UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	view = Panels.MapView.new()
	view.game = game
	view.trip_from = from_id
	view.trip_to = to_id
	view.vehicle = vehicle(from_id, to_id)
	view.custom_minimum_size = Vector2(800, 430)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(view)
	var hint := UiTheme.label("Any key to skip", 14, UiTheme.INK)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.6
	box.add_child(hint)

func _process(delta: float) -> void:
	if over: return
	t += delta
	if skipping and t < FADE + RIDE + HOLD: t = FADE + RIDE + HOLD
	card.modulate.a = alpha(t)
	view.trip_t = progress(t)
	view.queue_redraw()
	if t >= length():
		over = true
		done.emit()

func _input(event: InputEvent) -> void:
	if over: return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if pressed and t > FADE:
		skipping = true
		get_viewport().set_input_as_handled()
