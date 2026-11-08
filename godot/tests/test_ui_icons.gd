extends RefCounted
## The interface's icons come from bundled fonts (UiTheme.ICON_FONTS), so they look the same on every computer:
## every emoji or symbol in the game's scripts and data must be in Nunito, Fredoka or one of the icon fonts, or it
## would fall back to whatever the player's system has (or an empty box).
var t

## Characters that count as icons: anything outside Latin, Greek and Cyrillic text and general punctuation.
func _is_symbol(c: int) -> bool:
	if c < 0x2000: return false                       # Latin, accents, Greek, Cyrillic: text, not icons
	if c >= 0x2000 and c <= 0x206F: return false      # general punctuation (dashes, ellipsis, quotes)
	if c == 0xFE0F or c == 0xFE0E or c == 0x200D: return false   # emoji presentation selectors and joiners
	if c >= 0x1F3FB and c <= 0x1F3FF: return false    # skin-tone modifiers
	return true

func _symbols_in(root: String, found: Dictionary) -> void:
	var dir := DirAccess.open(root)
	if dir == null: return
	for f in dir.get_files():
		if not (f.ends_with(".gd") or f.ends_with(".json")): continue
		var text := FileAccess.get_file_as_string(root.path_join(f))
		for i in text.length():
			var c := text.unicode_at(i)
			if _is_symbol(c) and not found.has(c): found[c] = root.path_join(f)
	for d in dir.get_directories(): _symbols_in(root.path_join(d), found)

func test_every_icon_is_in_a_bundled_font():
	var fonts: Array[Font] = [load("res://assets/fonts/Nunito.ttf"), load("res://assets/fonts/Fredoka.ttf")]
	fonts.append_array(UiTheme.icon_fonts())
	var found := {}
	_symbols_in("res://scripts", found); _symbols_in("res://data", found)
	t.ok(found.size() > 100, "the scan finds the game's icons (%d)" % found.size())
	var missing: Array = []
	for c in found:
		var ok := false
		for f in fonts:
			if f.has_char(c): ok = true; break
		if not ok: missing.append("%s U+%X (%s)" % [String.chr(c), c, found[c]])
	t.ok(missing.is_empty(), "every icon is in a bundled font; missing: %s" % ", ".join(missing))

func test_ui_fonts_fall_back_to_the_icon_fonts_not_the_system():
	for f in [UiTheme.main_font(), UiTheme.title_font()]:
		# the drawn watercolour icons first (test_icons), then the one-colour icon fonts
		t.eq(f.fallbacks.size(), UiTheme.ICON_FONTS.size() + 1, "the UI font falls back to the drawn icons and the bundled icon fonts")
		t.eq(f.fallbacks[0], UiTheme.drawn_icon_font(), "the drawn icons come first")
		for fb in f.fallbacks: t.ok(not (fb is SystemFont), "no fallback reads the computer's own fonts")
	t.ok(UiTheme.main_font().has_char(0x1F344), "🍄 (porcini) has a glyph")
