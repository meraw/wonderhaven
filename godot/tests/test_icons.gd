extends RefCounted
## The watercolour icons (assets/fonts/WonderhavenIcons.ttf, built by tools/icons/render.cjs): the shared resources and
## the HUD's icons have a drawing, and the UI fonts try them before the one-colour icon fonts (test_ui_icons).
var t

## The HUD, the clock's weather, the journal and the menus.
const UI_ICONS := ["💖", "📜", "🗺", "🧭", "🔨", "🎒", "🕒", "💾", "📂", "⚙", "👗", "📈", "📐", "🔒", "📍", "📌", "💡", "🛍", "🎁", "💬",
	"☀", "🌙", "☁", "⛅", "🌦", "🌧", "🌨", "🌫", "🌅", "🌇", "🕛", "🪓", "⛏", "🎣", "★", "✔", "✕", "♥", "♡"]

func test_shared_resources_have_icons():
	var f := UiTheme.drawn_icon_font()
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/resources.json"))
	var missing := []
	for id in raw.resources:
		var icon := String(raw.resources[id].get("icon", ""))
		if icon != "" and not f.has_char(icon.unicode_at(0)): missing.append("%s %s" % [icon, id])
	t.ok(missing.is_empty(), "every shared resource has a watercolour icon (missing: %s)" % ", ".join(missing))

func test_hud_icons_are_drawn():
	var f := UiTheme.drawn_icon_font()
	var missing := UI_ICONS.filter(func(e): return not f.has_char(String(e).unicode_at(0)))
	t.ok(missing.is_empty(), "the HUD's icons are drawn (missing: %s)" % ", ".join(missing))

func test_ui_fonts_try_the_drawings_first():
	for font in [UiTheme.main_font(), UiTheme.title_font()]:
		t.ok(font.fallbacks.size() >= 2 and font.fallbacks[0] == UiTheme.drawn_icon_font(), "the drawn icons come before the one-colour icon fonts")
	# an emoji in a line of text is shaped in that line's script run: the icon font must claim Latin, as the emoji font does
	t.ok(UiTheme.drawn_icon_font().is_script_supported("Latn"), "the drawn icons are tried for emoji inside Latin text")
	t.ok(not UiTheme.marker_font().fallbacks.has(UiTheme.drawn_icon_font()), "the villagers' tinted markers keep a plain star")
