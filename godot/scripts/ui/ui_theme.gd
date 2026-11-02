class_name UiTheme
## Soft, rounded, cream-and-pink theme for every menu and HUD element.

const CREAM := Color("fff8ec")
const LINE := Color("ecc999")
const INK := Color("5a3d2b")
const INK2 := Color("8a6a50")
const PINK := Color("ff8fab")
const PINK_DARK := Color("e86f8f")
const GOLD := Color("ffcf5c")
const LILAC := Color("c9a8ff")

static func box(bg: Color, border: Color = LINE, radius: int = 18, bw: int = 3, pad: int = 10, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4; s.content_margin_right = pad + 4; s.content_margin_top = pad; s.content_margin_bottom = pad
	if shadow: s.shadow_color = Color(0.47, 0.31, 0.16, 0.22); s.shadow_size = 6; s.shadow_offset = Vector2(0, 4)
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = main_font()
	t.default_font_size = 17
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_stylebox("normal", "Button", box(CREAM, LINE, 999, 3, 6, false))
	t.set_stylebox("hover", "Button", box(Color("fffdf6"), PINK, 999, 3, 6, false))
	t.set_stylebox("pressed", "Button", box(PINK, PINK_DARK, 999, 3, 6, false))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), PINK, 999, 3, 6, false))
	t.set_stylebox("disabled", "Button", box(Color(CREAM, 0.6), Color(LINE, 0.6), 999, 3, 6, false))
	t.set_stylebox("panel", "PanelContainer", box(Color(CREAM, 0.95)))
	t.set_stylebox("panel", "Panel", box(Color(CREAM, 0.95)))
	t.set_color("font_color", "LineEdit", INK)
	t.set_stylebox("normal", "LineEdit", box(Color.WHITE, LINE, 12, 3, 6, false))
	t.set_stylebox("background", "ProgressBar", box(Color("f3e3c8"), Color("ecd2a8"), 999, 2, 0, false))
	t.set_stylebox("fill", "ProgressBar", box(PINK, PINK, 999, 0, 0, false))
	t.set_stylebox("panel", "TabContainer", box(Color(CREAM, 0.0), Color(0, 0, 0, 0), 0, 0, 0, false))
	return t

static var _font: SystemFont
## Rounded, friendly system fonts with a colour-emoji fallback for the icons (Windows, macOS and Linux names).
static func main_font() -> SystemFont:
	if _font: return _font
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Noto Color Emoji", "Segoe UI Emoji", "Apple Color Emoji", "Twemoji Mozilla"])
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Nunito", "Quicksand", "Varela Round", "Trebuchet MS", "Segoe UI", "Helvetica Neue", "Noto Sans", "DejaVu Sans"])
	_font.font_weight = 700
	_font.fallbacks = [emoji]
	return _font

static func primary(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", box(PINK, PINK_DARK, 999, 3, 6, false))
	b.add_theme_stylebox_override("hover", box(Color("ff9fb8"), PINK_DARK, 999, 3, 6, false))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b

static func label(text: String, size: int = 17, color: Color = INK, bold: bool = true) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold: l.add_theme_constant_override("outline_size", 0)
	return l

static func button(text: String, cb: Callable, is_primary: bool = false) -> Button:
	var b := Button.new(); b.text = text
	b.pressed.connect(cb)
	if is_primary: primary(b)
	return b

static func panel(bg: Color = Color(CREAM, 0.95), border: Color = LINE, radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, radius))
	return p
