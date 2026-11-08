# Icons

The game's icons are drawn here, in the watercolour-and-pencil style chosen from the icon directions (style E), and
built into a colour font, `godot/assets/fonts/WonderhavenIcons.ttf`.

The font puts each drawing at the code point of the emoji the game already writes: 🪵 is the pair of logs, 💖 the
approval rosette, ☀ the sun in the clock. The UI fonts (`godot/scripts/ui/ui_theme.gd`) fall back to it first, then
to the bundled one-colour icon fonts (Noto Emoji and symbols, `UiTheme.icon_fonts()`), so the game's text, data and
code keep their emoji and show these pictures. A symbol with no drawing here comes from the one-colour fonts.

## Files
- `icons.cjs`: the palette and one drawing per emoji, in a 64 × 64 box (see the comment at the top for the parts).
- `render.cjs`: renders every drawing to a 128 px PNG in `out/` (not committed), writes `out/sheet.png` to review
  them large and at HUD size, and builds the font.
- `build_font.py`: packs the PNGs into the font (an `sbix` colour bitmap table).

## Add or change an icon
1. Add or edit the drawing in `icons.cjs`, keyed by the emoji (without the `️` variation selector).
2. Run `node tools/icons/render.cjs` (needs Playwright with Chromium, and Python 3 with `fontTools`:
   `pip install fonttools`).
3. Look at `tools/icons/out/sheet.png`, then at the game. Commit `icons.cjs` and the font.

`godot/tests/test_icons.gd` checks that every shared resource and the HUD's icons have a drawing.

## Build pieces
The build pieces are pictures of the pieces themselves, not drawings: `godot/tests/render_piece_icons.gd` builds each
piece with the game's own model (`PieceMeshes.make`), lights it like the game (ACES, warm sun, ink outline), crops it
to its visible pixels and saves a 128 px PNG to `godot/assets/icons/pieces/<id>.png`. Build mode shows them on the
piece cards and in the selected-piece and draft panels (`BuildMode.piece_icon`); a locked piece shows its picture
faded. After adding a piece or changing its model, render again (Forward+ needs `mesa-vulkan-drivers` on a headless
machine) and commit the PNGs:

    xvfb-run -a godot --path godot --rendering-method forward_plus --rendering-driver vulkan -s res://tests/render_piece_icons.gd

Add `-- --only=bench,lamp` to render some pieces only. `test_icons.gd` checks that every piece has its picture.

## Not drawn yet
The other locations' own resources still come from the one-colour icon fonts.

## Notes on Godot
- Godot tries fallback fonts that claim the text's script first. An emoji inside English text is shaped with the
  Latin run around it, and emoji fonts usually claim Latin, so `UiTheme.drawn_icon_font()` sets a script override for
  Latin; without it the fonts after it would always win.
- Godot scales a colour bitmap font's strike to the text's size whatever size the strike declares, so an icon is made
  bigger by drawing it bigger in its PNG (`render.cjs` crops the drawings' margin, `VIEW`).
- The villagers' floating "!" and "★" are tinted glyphs, so they use `UiTheme.marker_font()`, which leaves the
  drawings out.
