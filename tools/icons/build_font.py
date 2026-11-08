"""build_font.py <out.ttf> <codepoint_hex>=<png> ...: a colour bitmap font (an sbix table) from square PNG icons,
one em wide and centred on the em box. Godot scales the one strike to the text's size (and ignores the strike's
declared size, so an icon is made bigger by drawing it bigger in its PNG: render.cjs crops the drawing's margin)."""
import sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib.tables._s_b_i_x import table__s_b_i_x
from fontTools.ttLib.tables.sbixStrike import Strike
from fontTools.ttLib.tables.sbixGlyph import Glyph as SbixGlyph

UPM = 1024
IMAGE = PPEM = 128     # the PNGs are 128 x 128, one em
ASC, DESC = 900, 124   # the em box, like the UI fonts' (Nunito)
ADVANCE = UPM

out = sys.argv[1]
items = []
for a in sys.argv[2:]:
    cp, png = a.split("=", 1)
    items.append((int(cp, 16), png))
names = [".notdef"] + ["u%04X" % cp for cp, _ in items]
fb = FontBuilder(UPM, isTTF=True)
fb.setupGlyphOrder(names)
fb.setupCharacterMap({cp: "u%04X" % cp for cp, _ in items})
empty = TTGlyphPen(None).glyph()
fb.setupGlyf({n: empty for n in names})
fb.setupHorizontalMetrics({n: (ADVANCE, 0) for n in names})
fb.setupHorizontalHeader(ascent=ASC, descent=-DESC)
fb.setupNameTable({"familyName": "Wonderhaven Icons", "styleName": "Regular"})
fb.setupOS2(sTypoAscender=ASC, sTypoDescender=-DESC, sTypoLineGap=0, usWinAscent=ASC, usWinDescent=DESC)
fb.setupPost()
sbix = table__s_b_i_x()
sbix.version = 1; sbix.flags = 1
strike = Strike(ppem=PPEM, resolution=72)
# centre the image on the em box: its middle sits (ASC - DESC) / 2 above the baseline
off_y = round((ASC - DESC) / 2 * PPEM / UPM - IMAGE / 2)
for cp, png in items:
    n = "u%04X" % cp
    strike.glyphs[n] = SbixGlyph(glyphName=n, graphicType="png ", originOffsetX=0, originOffsetY=off_y, imageData=open(png, "rb").read())
sbix.strikes[PPEM] = strike
fb.font["sbix"] = sbix
fb.save(out)
print("wrote", out, len(items), "glyphs")
