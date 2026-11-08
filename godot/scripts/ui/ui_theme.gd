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
const TEXT_SCALE := 0.88

static func px(size: int) -> int: return maxi(9, int(round(size * TEXT_SCALE)))

static func box(bg: Color, border: Color = LINE, radius: int = 18, bw: int = 3, pad: int = 8, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4; s.content_margin_right = pad + 4; s.content_margin_top = pad; s.content_margin_bottom = pad
	if shadow: s.shadow_color = Color(0.47, 0.31, 0.16, 0.22); s.shadow_size = 6; s.shadow_offset = Vector2(0, 4)
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = main_font()
	t.default_font_size = px(17)
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

static var _font: Font
static var _title: Font
static var _icons: Array[Font] = []
static var _drawn: FontFile
static var _marker: Font

## The interface's icons (the emoji and symbols in labels, buttons and data) come from bundled fonts, not the
## computer's: one-colour Noto Emoji, which takes the text's colour so icons match the ink and pink of the theme and
## look the same on Windows, macOS, Linux and the Steam Deck, then arrows, stars and dingbats from subsets of Noto Sans
## Symbols 2 and Noto Sans Math (all SIL Open Font License, see assets/fonts/Noto-OFL.txt). test_ui_icons checks
## every symbol the game uses is in one of them.
const ICON_FONTS := ["res://assets/fonts/NotoEmoji-UI.ttf", "res://assets/fonts/NotoSansSymbols2-UI.ttf", "res://assets/fonts/NotoSansMath-UI.ttf"]
const ICON_WEIGHT := 600   # Noto Emoji is a variable font (300 to 700); 600 sits with Nunito 750 and Fredoka 600

static func icon_fonts() -> Array[Font]:
	if _icons.is_empty():
		for path in ICON_FONTS:
			var f: FontFile = load(path)
			if path.ends_with("NotoEmoji-UI.ttf"):
				var fv := FontVariation.new(); fv.base_font = f
				fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): ICON_WEIGHT}
				_icons.append(fv)
			else: _icons.append(f)
	return _icons

## The game's own icons, drawn in watercolour and pencil, at the code points of the emoji the game writes (🪵 is the
## pair of logs, 💖 the approval rosette): a colour font built by tools/icons/render.cjs from tools/icons/icons.cjs.
## The UI fonts try it before the one-colour icon fonts, so text and data keep their emoji and show these pictures; a
## symbol with no drawing (the build pieces, so far) still comes from icon_fonts(). test_icons checks the coverage.
static func drawn_icon_font() -> FontFile:
	if _drawn == null:
		_drawn = load("res://assets/fonts/WonderhavenIcons.ttf")
		# An emoji inside a line of text belongs to that line's script run (Latin here), and fallback fonts that say
		# they support the run's script are tried first; without these overrides the icon fonts after this one would
		# be tried first and the drawings never used.
		for scr in ["Latn", "Zyyy", "Zsye"]: _drawn.set_script_support_override(scr, true)
	return _drawn

static func _variant(path: String, weight: int, drawn: bool = true) -> Font:
	var fv := FontVariation.new()
	fv.base_font = load(path)
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	var fallbacks: Array[Font] = []
	if drawn: fallbacks.append(drawn_icon_font())
	fallbacks.append_array(icon_fonts())
	fv.fallbacks = fallbacks
	return fv

## Body text: Nunito (bundled, SIL Open Font License), rounded and easy to read, with the drawn icons and the icon
## fonts as fallback.
static func main_font() -> Font:
	if _font == null: _font = _variant("res://assets/fonts/Nunito.ttf", 750)
	return _font

## The body font without the drawn icons, for glyphs drawn in a tint: the "!" and "★" floating over villagers.
static func marker_font() -> Font:
	if _marker == null: _marker = _variant("res://assets/fonts/Nunito.ttf", 750, false)
	return _marker

## Headings and big numbers: Fredoka (bundled, SIL Open Font License), soft and playful.
static func title_font() -> Font:
	if _title == null: _title = _variant("res://assets/fonts/Fredoka.ttf", 600)
	return _title

static func primary(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", box(PINK, PINK_DARK, 999, 3, 6, false))
	b.add_theme_stylebox_override("hover", box(Color("ff9fb8"), PINK_DARK, 999, 3, 6, false))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b

## Labels of 20 px and up are headings and use the title font.
static func label(text: String, size: int = 17, color: Color = INK, bold: bool = true) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", px(size))
	if size >= 20: l.add_theme_font_override("font", title_font())
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
