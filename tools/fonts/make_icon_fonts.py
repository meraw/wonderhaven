#!/usr/bin/env python3
"""Builds the interface's icon fonts (godot/assets/fonts/*-UI.ttf) from the Noto sources.

The game draws its icons (emoji and symbols in labels, buttons and data) from bundled fonts, not the computer's, so
they look the same everywhere and take the text's colour (UiTheme.ICON_FONTS). This script:
  - keeps all of Noto Emoji (one-colour, variable weight), so a new emoji in the data just works;
  - keeps only the arrows, maths operators, shapes, symbols and dingbats of Noto Sans Symbols 2 and Noto Sans Math;
  - gives all three the same short line height, within Nunito's and Fredoka's, so a line with an icon in it is no
    taller than one without (the symbol fonts' own metrics are much taller, which pushed panels into each other).

Usage (needs fontTools: pip install fonttools):
  python3 tools/fonts/make_icon_fonts.py --emoji 'NotoEmoji[wght].ttf' \
      --symbols2 NotoSansSymbols2-Regular.ttf --math NotoSansMath-Regular.ttf --out godot/assets/fonts
Sources: github.com/google/fonts, ofl/notoemoji, ofl/notosanssymbols2, ofl/notosansmath (SIL Open Font License).
Then run godot/run_tests.sh: test_ui_icons checks every symbol the game uses is in a bundled font.
"""
import argparse
import os

from fontTools import subset
from fontTools.ttLib import TTFont

# Unicode blocks kept from the symbol fonts.
SYMBOL_BLOCKS = [
    (0x2190, 0x21FF),  # arrows
    (0x2200, 0x22FF),  # mathematical operators
    (0x2300, 0x23FF),  # miscellaneous technical
    (0x25A0, 0x25FF),  # geometric shapes
    (0x2600, 0x26FF),  # miscellaneous symbols
    (0x2700, 0x27BF),  # dingbats
    (0x27C0, 0x27FF),  # maths symbols and supplemental arrows A
    (0x2900, 0x297F),  # supplemental arrows B
    (0x2B00, 0x2BFF),  # miscellaneous symbols and arrows
]

# Line metrics as fractions of the em: inside Nunito (1.01 / 0.35) and Fredoka (0.97 / 0.24).
ASCENT = 0.90
DESCENT = 0.22


def set_line_metrics(font: TTFont) -> None:
    upm = font["head"].unitsPerEm
    asc, desc = round(ASCENT * upm), round(DESCENT * upm)
    hhea, os2 = font["hhea"], font["OS/2"]
    hhea.ascent, hhea.descent, hhea.lineGap = asc, -desc, 0
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = asc, -desc, 0
    os2.usWinAscent, os2.usWinDescent = asc, desc
    os2.fsSelection |= 1 << 7  # USE_TYPO_METRICS


def subset_font(src: str, unicodes) -> TTFont:
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    font = subset.load_font(src, options)
    sub = subset.Subsetter(options)
    sub.populate(unicodes=unicodes)
    sub.subset(font)
    return font


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--emoji", required=True)
    ap.add_argument("--symbols2", required=True)
    ap.add_argument("--math", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    codes = [c for lo, hi in SYMBOL_BLOCKS for c in range(lo, hi + 1)]

    emoji = TTFont(a.emoji)
    set_line_metrics(emoji)
    emoji.save(os.path.join(a.out, "NotoEmoji-UI.ttf"))
    for src, name in ((a.symbols2, "NotoSansSymbols2-UI.ttf"), (a.math, "NotoSansMath-UI.ttf")):
        font = subset_font(src, codes)
        set_line_metrics(font)
        font.save(os.path.join(a.out, name))
    for name in ("NotoEmoji-UI.ttf", "NotoSansSymbols2-UI.ttf", "NotoSansMath-UI.ttf"):
        path = os.path.join(a.out, name)
        print(f"{name}: {os.path.getsize(path) // 1024} KB")


if __name__ == "__main__":
    main()
