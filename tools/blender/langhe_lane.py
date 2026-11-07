"""Langhe village houses: a modelling experiment (docs/MODELS.md).

    blender -b --factory-startup -P tools/blender/langhe_lane.py -- --out godot/assets/models/lab

Writes one .glb per house. Each is generated from a few parameters, but built the way a modeller would build it, out
of separate pieces: a footing of layered Langa sandstone, plaster walls that lean a little, curved coppi laid one by
one with a sagging ridge, wide eaves on rafter tails, louvred shutters (open, shut or ajar), iron balconies with
geraniums, a tobacconist's sign, a faded painted advert. Ambient occlusion and colour variation are baked into the
vertex colours.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

STONE = "b9ad97"      # pietra di Langa: grey-beige layered sandstone
BRICK = "a85a3c"
TILE = "b55a35"
FRAME = "ece4d2"      # window surrounds, painted a shade lighter than the wall
WINDOW = "f2eee4"     # white-painted window frames
GLASS = "39434d"
IRON = "2e2b29"
COPPER = "a8683a"
WOOD_DOOR = "6e4428"
POT = "b8643f"
LEAF = "4e7a3a"
GERANIUMS = ["d8344a", "e86f9a", "c42b3a"]
PITCH = math.radians(21.0)   # coppi roofs are low


class House:
    def __init__(self, name, w, d, floors, wall, shutter, seed, **opts):
        self.name, self.w, self.d, self.floors = name, w, d, floors
        self.wall, self.shutter, self.opts = wall, shutter, opts
        self.rng = random.Random(seed)
        self.body = kit.Builder(name + "_body", seed)
        self.fine = kit.Builder(name + "_fine", seed + 1)
        self.roof = kit.Builder(name + "_roof", seed + 2)
        self.extra = []                                   # lettering
        self.gf, self.fh = opts.get("gf", 2.7), 2.5    # ground floor and upper floor heights
        self.skip = []                                    # front openings the footing stops at: (x0, x1)
        self.attic = opts.get("attic", False)
        self.H = self.gf + self.fh * (floors - 1) + (0.75 if self.attic else 0.3)
        self.fy = -d / 2.0                                # the front wall's plane (front faces -Y)
        self.oh = 0.6                                     # eaves overhang, front and back
        self.rise = (d / 2.0) * math.tan(PITCH)
        self.trim_kind = "stone" if opts.get("trim") else "plaster"
        self.trim_col = opts.get("trim", FRAME)
        self.stone = opts.get("footing", STONE)

    # ---- walls --------------------------------------------------------------------------------------------------
    def walls(self):
        w, d, H = self.w, self.d, self.H
        self.body.box((0, 0, H / 2), (w, d, H), "plaster", self.wall, dice=0.45)
        prof = [(-d / 2, H - 0.01), (d / 2, H - 0.01), (0.0, H + self.rise - 0.05)]
        self.body.prism(prof, -w / 2, w / 2, "plaster", self.wall)
        self.body.lean(0.035, seed=self.rng.randint(0, 999))
        self.footing()
        for _ in range(self.opts.get("patches", 0)):
            self.brick_patch()
        for f in range(1, self.floors):            # a plaster band at each floor (marcapiano), a shade lighter
            z = self.gf + self.fh * (f - 1)
            self.fine.box((0, self.fy - 0.03, z - 0.08), (w + 0.04, 0.07, 0.16), self.trim_kind, self.trim_col, tint=(0.97, 0.97, 0.97))
        self.fine.box((0, self.fy - 0.06, H - 0.12), (w + 0.04, 0.13, 0.22), self.trim_kind, self.trim_col)   # cornice under the eaves
        if self.opts.get("quoins"):
            self.quoins(self.opts["quoins"])

    def footing(self):
        """A band of layered sandstone at the foot of the walls, slabs of random length, each a little proud."""
        top = 0.75
        w, d, b = self.w, self.d, self.fine
        for side in ("front", "back", "left", "right"):
            length = w if side in ("front", "back") else d
            z = 0.0
            while z < top - 0.03:
                h = min(self.rng.uniform(0.08, 0.17), top - z)
                s = -length / 2 - self.rng.uniform(0.0, 0.3)
                while s < length / 2:
                    L = self.rng.uniform(0.2, 0.62)
                    a, c = max(s, -length / 2), min(s + L, length / 2)
                    if side == "front":
                        for o0, o1 in self.skip:        # stop at doorways and shopfronts
                            if a < o1 and c > o0:       # overlaps: keep the part left of the opening, else right
                                if a < o0:
                                    c = o0
                                else:
                                    a = max(a, o1)
                    if c - a > 0.06:
                        depth = self.rng.uniform(0.03, 0.075)
                        mid, size = (a + c) / 2, c - a - 0.014
                        tint = b.vary(0.1, 0.05)
                        if side == "front":
                            b.box((mid, -d / 2 - depth / 2 + 0.015, z + h / 2), (size, depth + 0.03, h - 0.014), "stone", self.stone, tint=tint)
                        elif side == "back":
                            b.box((mid, d / 2 + depth / 2 - 0.015, z + h / 2), (size, depth + 0.03, h - 0.014), "stone", self.stone, tint=tint)
                        elif side == "left":
                            b.box((-w / 2 - depth / 2 + 0.015, mid, z + h / 2), (depth + 0.03, size, h - 0.014), "stone", self.stone, tint=tint)
                        else:
                            b.box((w / 2 + depth / 2 - 0.015, mid, z + h / 2), (depth + 0.03, size, h - 0.014), "stone", self.stone, tint=tint)
                    s += L
                z += h

    def brick_patch(self):
        """Where the plaster has fallen off: an irregular patch of brick showing through."""
        w = self.w
        cx = self.rng.uniform(-w / 2 + 0.8, w / 2 - 0.8)
        cz = self.rng.uniform(1.0, self.H - 0.8)
        rx, rz = self.rng.uniform(0.35, 0.7), self.rng.uniform(0.2, 0.42)
        row = 0
        z = cz - rz
        while z < cz + rz:
            x = cx - rx - (0.12 if row % 2 else 0.0)
            while x < cx + rx:
                px, pz = x + 0.12, z + 0.035
                edge = ((px - cx) / rx) ** 2 + ((pz - cz) / rz) ** 2
                if edge < 0.85 + 0.25 * self.rng.random():
                    self.fine.box((px, self.fy - 0.006, pz), (0.225, 0.03, 0.062), "brick", BRICK, tint=self.fine.vary(0.12, 0.06))
                x += 0.25
            z += 0.075
            row += 1

    # ---- openings -----------------------------------------------------------------------------------------------
    def window(self, cx, zb, ww, wh, state=None, grate=False):
        b, fy = self.fine, self.fy
        b.box((cx, fy - 0.015, zb + wh / 2), (ww, 0.04, wh), "glass", GLASS)
        b.box((cx, fy - 0.05, zb + wh + 0.06), (ww + 0.22, 0.09, 0.12), self.trim_kind, self.trim_col)           # lintel
        b.box((cx, fy - 0.09, zb - 0.04), (ww + 0.3, 0.18, 0.08), "stone", "cfc6b4")                 # sill
        for s in (-1, 1):
            b.box((cx + s * (ww / 2 + 0.05), fy - 0.04, zb + wh / 2), (0.1, 0.07, wh), self.trim_kind, self.trim_col)
        b.box((cx, fy - 0.045, zb + wh / 2), (0.045, 0.03, wh), "wood", WINDOW)                      # frames
        b.box((cx, fy - 0.045, zb + wh * 0.62), (ww, 0.03, 0.045), "wood", WINDOW)
        if grate:
            for i in range(5):
                b.box((cx - ww / 2 + ww * (i + 0.5) / 5, fy - 0.11, zb + wh / 2), (0.022, 0.022, wh), "iron", IRON)
            for zz in (zb + 0.12, zb + wh - 0.12):
                b.box((cx, fy - 0.11, zz), (ww, 0.022, 0.022), "iron", IRON)
        state = state or self.opts.get("shutters") or self.rng.choice(["open", "open", "open", "shut", "ajar", "half"])
        angles = {"open": (178, 178), "shut": (0, 0), "ajar": (110, 135), "half": (178, 0)}[state]
        for side, ang in zip((-1, 1), angles):
            self.shutter_leaf(cx + side * ww / 2, zb, ww / 2, wh, side, ang)

    def other_faces(self, xs):
        """Windows on the back and on both side walls: built on the front, then turned to their wall. Shutters there are
        open or shut, never ajar, so they don't poke into a neighbour's wall."""
        w, d, gf, fh = self.w, self.d, self.gf, self.fh
        b = self.fine
        for face, angle, half, spots in (("back", math.pi, d / 2, xs),
                                          ("right", math.pi / 2, w / 2, [-d / 4, d / 4]),
                                          ("left", -math.pi / 2, w / 2, [-d / 4, d / 4])):
            fy = self.fy
            self.fy = -half
            since = b.mark()
            for f in range(self.floors):
                for x in spots:
                    state = self.rng.choice(["open", "open", "shut"])
                    if f == 0:
                        if face == "back":
                            self.window(x, 0.95, 0.8, 1.15, state=state, grate=True)
                    else:
                        self.window(x, gf + fh * (f - 1) + 0.75, 0.8, 1.25, state=state)
            b.turn(since, angle)
            self.fy = fy

    def quoins(self, col):
        w, d, H = self.w, self.d, self.H
        b = self.fine
        z, k = 0.78, 0
        while z < H - 0.3:
            h = 0.34
            long_front = k % 2 == 0
            fx, fz = (0.56, 0.3) if long_front else (0.3, 0.56)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    b.box((sx * (w / 2 - fx / 2 + 0.04), sy * (d / 2 - fz / 2 + 0.04), z + h / 2), (fx, fz, h),
                          "stone", col, tint=b.vary(0.07, 0.03))
            z += h + 0.03
            k += 1

    def portico(self, n):
        w, gf, fy = self.w, self.gf, self.fy
        b = self.fine
        depth = 1.75
        y = fy - depth
        for i in range(n):
            x = -w / 2 + 0.3 + i * (w - 0.6) / (n - 1)
            b.box((x, y, (gf - 0.32) / 2 + 0.1), (0.36, 0.36, gf - 0.52), "stone", self.trim_col, tint=b.vary(0.05))
            b.box((x, y, 0.08), (0.5, 0.5, 0.16), "stone", self.trim_col, tint=b.vary(0.05))
            b.box((x, y, gf - 0.36), (0.5, 0.5, 0.14), "stone", self.trim_col, tint=b.vary(0.05))
        b.box((0, y, gf - 0.12), (w + 0.12, 0.46, 0.34), "stone", self.trim_col, tint=b.vary(0.04))
        for sx in (-1, 1):
            b.box((sx * (w / 2 - 0.3 + 0.06), fy - depth / 2, gf - 0.12), (0.4, depth, 0.34), "stone", self.trim_col)
        b.box((0, fy - depth / 2, gf + 0.08), (w + 0.12, depth + 0.1, 0.1), "stone", self.trim_col)
        b.box((0, fy - depth / 2, 0.025), (w + 0.1, depth + 0.3, 0.05), "stone", "cfc6b4", tint=b.vary(0.04))

    def shutter_leaf(self, hinge_x, zb, lw, lh, side, angle_deg):
        """A louvred shutter leaf hinged at hinge_x: 0 degrees shut over the window, 180 folded back against the wall."""
        a = math.radians(angle_deg)
        dx, dy = (-side * math.cos(a), -math.sin(a))     # from the hinge toward the leaf's free edge
        y0 = self.fy - 0.07
        theta = math.atan2(dy, dx)
        cx, cy = hinge_x + dx * lw / 2, y0 + dy * lw / 2
        if angle_deg > 170:
            cy = self.fy - 0.03
        b = self.fine
        tint = b.vary(0.04)
        b.box((cx, cy, zb + lh / 2), (lw - 0.01, 0.03, lh), "wood", self.shutter, rot=(0, 0, theta), tint=tint)
        nx, ny = (-dy, dx) if side < 0 else (dy, -dx)    # the leaf's outer face
        if ny > 0:
            nx, ny = -nx, -ny
        n = int((lh - 0.14) / 0.105)
        for i in range(n):
            z = zb + 0.09 + i * 0.105
            b.box((cx + nx * 0.022, cy + ny * 0.022, z), (lw - 0.08, 0.016, 0.045), "wood", self.shutter,
                  rot=(math.radians(-25), 0, theta), tint=tint)

    def door_arched(self, cx, dw=1.25, dh=2.05):
        b, fy = self.fine, self.fy
        spring = dh - dw / 2
        R = dw / 2 + 0.1
        for s in (-1, 1):
            b.box((cx + s * (dw / 2 + 0.1), fy - 0.05, spring / 2), (0.2, 0.1, spring), "stone", "cdc3ae", tint=b.vary(0.05))
        n = 9
        for i in range(n):
            ang = math.pi * (i + 0.5) / n
            big = 1.18 if i == n // 2 else 1.0                       # the keystone
            b.box((cx + R * math.cos(ang), fy - 0.05, spring + R * math.sin(ang)),
                  (0.25 * big, 0.1, 0.2 * big), "stone", "cdc3ae", rot=(0, math.pi / 2 - ang, 0), tint=b.vary(0.07))
        b.cylinder((cx, fy - 0.02, spring), dw / 2, 0.03, "glass", GLASS, rot=(math.pi / 2, 0, 0), segments=16)
        for k in (-1, 0, 1):
            ang = math.pi / 2 + k * 0.55
            b.box((cx + math.cos(ang) * dw / 4, fy - 0.04, spring + math.sin(ang) * dw / 4), (0.02, 0.02, dw / 2),
                  "iron", IRON, rot=(0, math.pi / 2 - ang, 0))
        planks = 5
        for i in range(planks):
            px = cx - dw / 2 + dw * (i + 0.5) / planks
            b.box((px, fy - 0.035, spring / 2), (dw / planks - 0.012, 0.05, spring), "wood", WOOD_DOOR, tint=b.vary(0.08))
        b.box((cx, fy - 0.07, spring - 0.04), (dw, 0.04, 0.08), "wood", WOOD_DOOR)
        b.cylinder((cx + dw * 0.3, fy - 0.08, 1.0), 0.035, 0.03, "metal", "c9a24a", rot=(math.pi / 2, 0, 0))
        b.box((cx, fy - 0.3, 0.06), (dw + 0.5, 0.5, 0.12), "stone", "c4baa6", tint=b.vary(0.05))     # the step

    def door_plain(self, cx, dw=1.1, dh=2.05):
        b, fy = self.fine, self.fy
        b.box((cx, fy - 0.05, dh + 0.08), (dw + 0.34, 0.1, 0.16), "stone", "cdc3ae")
        for s in (-1, 1):
            b.box((cx + s * (dw / 2 + 0.08), fy - 0.05, dh / 2), (0.16, 0.1, dh), "stone", "cdc3ae", tint=b.vary(0.05))
        for i in range(2):
            b.box((cx + (i - 0.5) * dw / 2, fy - 0.035, dh / 2), (dw / 2 - 0.02, 0.05, dh), "wood", self.opts.get("door", "5a6b4a"), tint=b.vary(0.06))
            for zz in (0.45, 1.25):
                b.box((cx + (i - 0.5) * dw / 2, fy - 0.065, zz), (dw / 2 - 0.16, 0.02, 0.55), "wood", self.opts.get("door", "5a6b4a"), tint=b.vary(0.08))
        b.box((cx, fy - 0.25, 0.06), (dw + 0.4, 0.4, 0.12), "stone", "c4baa6")

    def shop(self, cx, ws, sign, sign_color="2b2622"):
        """A shopfront: a wooden frame round a big window and a glazed door, a painted sign band, a striped awning."""
        b, fy, gf = self.fine, self.fy, self.gf
        frame = self.opts.get("shopframe", "35503f")
        b.box((cx, fy - 0.02, 1.2), (ws, 0.04, 2.1), "glass", GLASS)
        for x in (cx - ws / 2, cx + ws / 2, cx - 0.55, cx + 0.55):
            b.box((x, fy - 0.06, 1.15), (0.12, 0.1, 2.3), "wood", frame)
        b.box((cx, fy - 0.06, 2.3), (ws + 0.12, 0.1, 0.12), "wood", frame)
        b.box((cx, fy - 0.06, 0.25), (ws + 0.12, 0.12, 0.5), "wood", frame)
        b.box((cx, fy - 0.07, 1.05), (1.0, 0.05, 2.0), "wood", frame)                     # the door
        b.box((cx, fy - 0.1, 1.25), (0.8, 0.02, 1.2), "glass", GLASS)
        b.box((cx, fy - 0.06, 2.62), (ws + 0.3, 0.07, 0.44), "paint", "e9dfc7")             # sign band
        self.extra.append(kit.text(sign, 0.27, "paint", sign_color, (cx, fy - 0.1, 2.62)))
        # awning: canvas stripes sloping out over the window
        stripes = 9
        aw = ws + 0.2
        for i in range(stripes):
            col = "ece3d0" if i % 2 == 0 else self.opts.get("awning", "b5452f")
            b.box((cx - aw / 2 + aw * (i + 0.5) / stripes, fy - 0.45, 2.22), (aw / stripes, 0.95, 0.03), "paint", col,
                  rot=(math.radians(-24), 0, 0))
        for i in range(stripes):   # a scalloped valance along the front edge
            col = "ece3d0" if i % 2 == 0 else self.opts.get("awning", "b5452f")
            b.box((cx - aw / 2 + aw * (i + 0.5) / stripes, fy - 0.89, 1.96), (aw / stripes, 0.025, 0.16), "paint", col)

    def tabacchi_sign(self, x, z):
        """The tobacconist's projecting sign: a white T on dark blue, read from both ways along the street."""
        b, fy = self.fine, self.fy
        b.box((x, fy - 0.2, z + 0.42), (0.04, 0.4, 0.04), "iron", IRON)
        b.box((x, fy - 0.42, z), (0.07, 0.42, 0.62), "paint", "1f2f5a")
        for s in (-1, 1):
            self.extra.append(kit.text("T", 0.5, "paint", "f4f1e8", (x + s * 0.04, fy - 0.42, z),
                                       rot=(math.pi / 2, 0, s * math.pi / 2), depth=0.003))

    def balcony(self, cx, z):
        b, fy = self.fine, self.fy
        bw, bd = 1.9, 0.62
        self.window(cx, z + 0.06, 1.0, 2.0, state="open")
        b.box((cx, fy - bd / 2, z), (bw, bd, 0.12), "stone", "cfc6b4", tint=b.vary(0.04))
        for s in (-0.7, 0.0, 0.7):
            b.box((cx + s, fy - 0.2, z - 0.2), (0.08, 0.36, 0.08), "iron", IRON, rot=(math.radians(35), 0, 0))
        top = z + 0.06 + 0.95
        ry = fy - bd + 0.04
        b.box((cx, ry, top), (bw, 0.045, 0.045), "iron", IRON)
        b.box((cx, ry, z + 0.14), (bw, 0.03, 0.03), "iron", IRON)
        for s in (-1, 1):
            b.box((cx + s * (bw / 2 - 0.02), fy - bd / 2, top), (0.045, bd, 0.045), "iron", IRON)
        n = int(bw / 0.11)
        for i in range(n + 1):
            b.box((cx - bw / 2 + 0.02 + i * (bw - 0.04) / n, ry, z + 0.06 + 0.48), (0.02, 0.02, 0.9), "iron", IRON)
        for s in (-1, 1):
            for k in range(1, 5):
                b.box((cx + s * (bw / 2 - 0.02), fy - k * bd / 5, z + 0.06 + 0.48), (0.02, 0.02, 0.9), "iron", IRON)
        for i, px in enumerate((-0.6, 0.0, 0.6)):          # geraniums spilling over the rail
            b.cylinder((cx + px, ry + 0.16, top - 0.08), 0.13, 0.2, "brick", POT, radius2=0.1, rot=(0, 0, 0), segments=10,
                       tint=b.vary(0.06))
            self.flowers(cx + px, ry + 0.1, top + 0.08, spill=True)

    def flowers(self, x, y, z, spill=False):
        b = self.fine
        for k in range(4):
            b.blob((x + self.rng.uniform(-0.16, 0.16), y + self.rng.uniform(-0.12, 0.06), z + self.rng.uniform(-0.04, 0.06)),
                   self.rng.uniform(0.1, 0.15), "leaf", LEAF, squash=0.7, tint=b.vary(0.1, 0.05))
        if spill:
            for k in range(3):
                b.blob((x + self.rng.uniform(-0.2, 0.2), y - 0.12, z - 0.18 - k * 0.09), 0.09, "leaf", LEAF, squash=0.9,
                       tint=b.vary(0.1))
        col = self.rng.choice(GERANIUMS)
        for k in range(6):
            b.blob((x + self.rng.uniform(-0.18, 0.18), y + self.rng.uniform(-0.16, 0.04), z + self.rng.uniform(0.04, 0.14)),
                   self.rng.uniform(0.045, 0.065), "flower", col, tint=b.vary(0.08))

    def ghost_sign(self, words, z, side=1):
        """An old painted advert high on a side wall, faded into the plaster."""
        x = side * (self.w / 2 + 0.004)
        self.fine.box((x, 0.0, z), (0.012, 3.6, 0.9), "paint", "a9584a", tint=(0.92, 0.9, 0.88))
        self.extra.append(kit.text(words, 0.34, "paint", "efe3c6", (x + side * 0.008, 0.0, z),
                                   rot=(math.pi / 2, 0, side * math.pi / 2), depth=0.002))

    def sundial(self, cx, z):
        """A meridiana: a painted sundial with its hour lines and an iron rod."""
        b, fy = self.fine, self.fy
        b.box((cx, fy - 0.008, z), (1.3, 0.02, 1.05), "paint", "6b4a35")
        b.box((cx, fy - 0.014, z), (1.18, 0.02, 0.93), "paint", "f0e6cf")
        for k in range(-4, 5):
            a = k * 0.27
            L = 0.75 if k % 2 == 0 else 0.6
            b.box((cx + math.sin(a) * L / 2, fy - 0.026, z + 0.38 - math.cos(a) * L / 2), (0.014, 0.008, L), "paint", "3d2f26",
                  rot=(0, a, 0))
        b.box((cx, fy - 0.2, z + 0.25), (0.018, 0.4, 0.018), "iron", IRON, rot=(math.radians(-35), 0, 0))
        self.extra.append(kit.text("MCMXCIX", 0.09, "paint", "3d2f26", (cx, fy - 0.03, z - 0.38)))

    def number_plate(self, x, z, num):
        self.fine.box((x, self.fy - 0.012, z), (0.24, 0.02, 0.17), "paint", "f2efe6")
        self.extra.append(kit.text(num, 0.12, "paint", "1d2a4a", (x, self.fy - 0.025, z)))

    def wall_lamp(self, x, z):
        b, fy = self.fine, self.fy
        b.box((x, fy - 0.2, z + 0.25), (0.035, 0.4, 0.035), "iron", IRON)
        b.cylinder((x, fy - 0.38, z), 0.11, 0.26, "glass", "f3d9a0", segments=8, radius2=0.14)
        b.cylinder((x, fy - 0.38, z + 0.17), 0.16, 0.08, "iron", IRON, segments=8, radius2=0.04)

    # ---- roof ---------------------------------------------------------------------------------------------------
    def roof_tiles(self):
        w, d, H, oh, rise = self.w, self.d, self.H, self.oh, self.rise
        side_oh = 0.28
        W = w + 2 * side_oh
        run = d / 2 + oh
        slope = run / math.cos(PITCH)
        ridge = Vector((0.0, 0.0, H + rise))
        r = self.roof
        sag = self.opts.get("sag", 0.04)
        for sgn in (-1, 1):   # front (-Y) and back (+Y) slopes
            down = Vector((0.0, sgn * math.cos(PITCH), -math.sin(PITCH)))
            nrm = Vector((0.0, sgn * math.sin(PITCH), math.cos(PITCH)))
            r.box(tuple(ridge + down * slope / 2 - nrm * 0.03), (W, slope, 0.06), "wood", "5e4632",
                  rot=(-sgn * PITCH, 0, 0))
            pitch_x = 0.34
            cols = int(W / pitch_x)
            x0 = -cols * pitch_x / 2
            step, length = 0.36, 0.44
            rows = int(slope / step) + 1
            for c in range(cols * 2 + 1):
                cap = c % 2 == 1
                u = x0 + c * pitch_x / 2
                lift_end = sag * (1.0 - math.sin(math.pi * min(1.0, max(0.0, (u - x0) / (cols * pitch_x)))))
                for k in range(rows):
                    y = slope - length - k * step + self.rng.uniform(-0.02, 0.02)
                    if y < -0.02:
                        y = -0.02
                    xj = u + self.rng.uniform(-0.012, 0.012)
                    tz = 0.045 if cap else 0.0
                    yaw = math.radians(self.rng.uniform(-2.5, 2.5))
                    origin = ridge + Vector((xj, 0, 0)) + down * y + nrm * (tz + lift_end)
                    x_axis = Vector((math.cos(yaw), math.sin(yaw) * -sgn, 0)).normalized()
                    y_axis = nrm.cross(x_axis).normalized() * (-1 if sgn < 0 else 1)
                    if y_axis.dot(down) < 0:
                        y_axis = -y_axis
                    z_axis = x_axis.cross(y_axis)
                    if z_axis.dot(nrm) < 0:
                        z_axis = -z_axis
                    frame = Matrix((
                        (x_axis.x, y_axis.x, z_axis.x, origin.x),
                        (x_axis.y, y_axis.y, z_axis.y, origin.y),
                        (x_axis.z, y_axis.z, z_axis.z, origin.z),
                        (0, 0, 0, 1)))
                    roll = self.rng.random()
                    tint = r.vary(0.1, 0.05)
                    if roll < 0.05:
                        tint = (tint[0] * 0.72, tint[1] * 0.8, tint[2] * 0.62)        # lichen
                    elif roll < 0.11:
                        tint = (tint[0] * 1.12, tint[1] * 1.08, tint[2] * 1.0)        # a newer tile
                    r.tile(frame, 0.2 if cap else pitch_x, length, "roof", TILE, convex=cap, tint=tint)
        # ridge caps along the top, on a mortar bed
        r.box((0, 0, H + rise + 0.02), (W, 0.22, 0.08), "plaster", "d8cdb8")
        n = int(W / 0.38) + 1
        for i in range(n):
            x = -W / 2 + i * W / n
            frame = Matrix(((0, -1, 0, x), (1, 0, 0, 0), (0, 0, 1, H + rise + 0.06), (0, 0, 0, 1)))
            frame = Matrix(((0, 1, 0, x), (-1, 0, 0, 0), (0, 0, 1, H + rise + 0.06), (0, 0, 0, 1)))
            r.tile(frame, 0.26, 0.42, "roof", TILE, convex=True, tint=r.vary(0.1, 0.04))
        # eaves: fascia, copper gutter, rafter tails; barge boards at the gables
        b = self.fine
        for sgn in (-1, 1):
            ey = sgn * (d / 2 + oh)
            ez = H + rise - run * math.tan(PITCH)
            b.box((0, ey - sgn * 0.02, ez - 0.07), (W, 0.05, 0.14), "wood", "5e4632")
            b.cylinder((0, ey + sgn * 0.05, ez - 0.1), 0.065, W, "metal", COPPER, rot=(0, math.pi / 2, 0), segments=10)
            nraf = int(w / 0.5)
            for i in range(nraf + 1):
                x = -w / 2 + 0.1 + i * (w - 0.2) / nraf
                yy = sgn * (d / 2 + oh / 2)
                zz = H + rise - (d / 2 + oh / 2) * math.tan(PITCH) - 0.13
                b.box((x, yy, zz), (0.085, oh + 0.06, 0.12), "wood", "6a4e36", rot=(-sgn * PITCH, 0, 0), tint=b.vary(0.08))
        for s in (-1, 1):
            for sgn in (-1, 1):
                down = Vector((0.0, sgn * math.cos(PITCH), -math.sin(PITCH)))
                c = ridge + down * slope / 2 + Vector((s * W / 2, 0, -0.02))
                b.box(tuple(c), (0.05, slope, 0.2), "wood", "5e4632", rot=(-sgn * PITCH, 0, 0))

    def chimney(self, x, y):
        b = self.fine
        H, rise, d = self.H, self.rise, self.d
        z_roof = H + rise - abs(y) * math.tan(PITCH)
        top = H + rise + 0.9
        h = top - (z_roof - 0.3)
        b.box((x, y, (z_roof - 0.3) + h / 2), (0.55, 0.55, h), "brick", BRICK, tint=b.vary(0.06))
        for cx in (-0.2, 0.2):
            for cy in (-0.2, 0.2):
                b.box((x + cx, y + cy, top + 0.15), (0.12, 0.12, 0.3), "brick", BRICK, tint=b.vary(0.08))
        b.box((x, y, top + 0.33), (0.75, 0.75, 0.06), "stone", "cfc6b4")
        for sgn in (-1, 1):   # a little coppi roof on the chimney
            b.box((x, y + sgn * 0.2, top + 0.43), (0.8, 0.46, 0.05), "roof", TILE, rot=(-sgn * math.radians(28), 0, 0))

    def downpipe(self, x):
        b = self.fine
        y = self.fy - self.oh + 0.12
        top = self.H + self.rise - (self.d / 2 + self.oh) * math.tan(PITCH) - 0.15
        b.cylinder((x, self.fy - 0.08, (top + 0.25) / 2 + 0.05), 0.05, top - 0.35, "metal", COPPER, segments=8)
        b.cylinder((x, (y + self.fy - 0.08) / 2, top - 0.05), 0.05, abs(y - (self.fy - 0.08)) + 0.1, "metal", COPPER,
                   rot=(math.pi / 2, 0, 0), segments=8)
        for z in (1.0, 2.6, 4.2):
            if z < top - 0.2:
                b.box((x, self.fy - 0.04, z), (0.14, 0.08, 0.04), "iron", IRON)

    def bench(self, x):
        b, fy = self.fine, self.fy
        for i in range(3):
            b.box((x, fy - 0.42 + i * 0.12, 0.46), (1.5, 0.1, 0.04), "wood", "9a6b42", tint=b.vary(0.06))
        b.box((x, fy - 0.1, 0.78), (1.5, 0.04, 0.22), "wood", "9a6b42")
        for s in (-0.65, 0.65):
            b.box((x + s, fy - 0.3, 0.23), (0.06, 0.4, 0.46), "iron", IRON)

    # ---- assembly -----------------------------------------------------------------------------------------------
    def build(self):
        o = self.opts
        w, gf, fh = self.w, self.gf, self.fh
        slots = max(1, round((w - 0.6) / 1.75))
        xs = [-w / 2 + w * (i + 0.5) / slots for i in range(slots)]
        door_i = o.get("door_slot", slots // 2)
        gwin = o.get("gwin", (0.85, 1.2))
        uwin = o.get("win", (0.85, 1.3))
        if o.get("shop"):
            self.skip.append((-(w - 1.4) / 2 - 0.1, (w - 1.4) / 2 + 0.1))
        else:
            dw = 1.25 + 0.4 if o.get("arch", True) else 1.1 + 0.32
            self.skip.append((xs[door_i] - dw / 2, xs[door_i] + dw / 2))
        self.walls()
        # ground floor
        if o.get("shop"):
            self.shop(0.0, w - 1.4, o["shop"])
            if o.get("tabacchi"):
                self.tabacchi_sign(w / 2 - 0.35, 2.6)
        else:
            for i, x in enumerate(xs):
                if i == door_i:
                    (self.door_arched if o.get("arch", True) else self.door_plain)(x)
                else:
                    self.window(x, 0.95, gwin[0], gwin[1], grate=o.get("grates", True))
        # upper floors
        for f in range(1, self.floors):
            z = gf + fh * (f - 1)
            for i, x in enumerate(xs):
                if f == 1 and o.get("balcony") and i == door_i:
                    self.balcony(x, z)
                else:
                    self.window(x, z + 0.7, uwin[0], uwin[1])
        if self.attic:
            z = self.H - 0.62
            for x in xs:
                self.fine.box((x, self.fy - 0.02, z), (0.42, 0.04, 0.34), "glass", GLASS)
                self.fine.box((x, self.fy - 0.05, z - 0.21), (0.55, 0.12, 0.06), "stone", "cfc6b4")
        if o.get("sundial"):
            self.sundial(xs[0] if len(xs) > 1 else 0.0, self.H - (1.3 if not self.attic else 1.75))
        if o.get("ghost"):
            self.ghost_sign(o["ghost"], self.H - 1.2, side=o.get("ghost_side", 1))
        if o.get("number"):
            self.number_plate(xs[door_i] + 0.95, 2.0, o["number"])
        if o.get("lamp"):
            self.wall_lamp(xs[door_i] - 0.95, 2.45)
        if o.get("bench"):
            self.bench(xs[(door_i + 1) % len(xs)] if len(xs) > 1 else 0.0)
        if o.get("pots"):
            for k, x in enumerate(xs):
                if k != door_i:
                    self.fine.cylinder((x + 0.55, self.fy - 0.35, 0.15), 0.17, 0.3, "brick", POT, radius2=0.13, tint=self.fine.vary(0.06))
                    self.flowers(x + 0.55, self.fy - 0.35, 0.36)
        if o.get("portico"):
            self.portico(o["portico"])
        self.other_faces(xs)
        self.roof_tiles()
        self.chimney(o.get("chimney_x", w * 0.22), self.d * 0.18)
        self.downpipe(w / 2 - 0.15 if o.get("pipe_side", 1) > 0 else -w / 2 + 0.15)

        body = self.body.finish(bevel=0.035, segments=2)
        fine = self.fine.finish()          # small parts: a bevel here costs triangles the camera never sees
        roof = self.roof.finish()
        parts = [body, fine, roof] + self.extra
        for p in parts:
            others = [q for q in parts if q is not p]
            kit.bake_colors(p, occluders=others, damp_height=0.6 + 0.75 if p is body else 0.0)
        return kit.join(parts, self.name)


HOUSES = [
    # name, width, depth, floors, wall, shutters, seed, options
    ("casa_ocra", 5.2, 6.0, 2, "d8a557", "4f6b43", 11,
     dict(balcony=True, number="12", lamp=True, pots=True, patches=1, chimney_x=1.2)),
    ("tabaccheria", 6.2, 6.4, 3, "d9a093", "7a4b2e", 23,
     dict(shop="SALI E TABACCHI", tabacchi=True, gf=3.2, ghost="AMARO DEL BRICCO", balcony=True, sag=0.06, chimney_x=-1.6)),
    ("casa_crema", 4.6, 6.0, 2, "e6d6b4", "6f8090", 37,
     dict(arch=False, door="5a6b4a", patches=3, bench=True, door_slot=0, pipe_side=-1, chimney_x=-0.8)),
    ("casa_gialla", 5.6, 6.2, 3, "e2bd6e", "3f5a3a", 41,
     dict(attic=True, sundial=True, balcony=True, number="14", pots=True, chimney_x=1.5, sag=0.05)),
]


def main():
    a = kit.args()
    out = a.get("out", "godot/assets/models/lab")
    only = a.get("only", "")
    for name, w, d, floors, wall, shutter, seed, opts in HOUSES:
        if only and name not in only.split(","):
            continue
        kit.reset()
        ob = House(name, w, d, floors, wall, shutter, seed, **opts).build()
        kit.export_glb([ob], os.path.join(out, name + ".glb"))
        if a.get("blend"):
            kit.save_blend(os.path.join(a["blend"], name + ".blend"))


if __name__ == "__main__":
    main()
