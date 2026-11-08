import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import kit
from langhe_lane import GLASS, IRON, POT, TILE, WOOD_DOOR, House
from mathutils import Matrix

SHUTTER = "2f4f37"
TRIM = "e8dcc4"
DOOR = "5a6b4a"
SHOPFRAME = "35503f"
BRICK = "a85a3c"
SHUTTER_ANGLES = (0, 110, 135, 178)


def house(seed, quiet=False):
    h = House("part", 4.0, 4.0, 1, "e0c9a0", SHUTTER, seed, trim=TRIM, door=DOOR, shopframe=SHOPFRAME)
    h.fy = 0.0
    if quiet:
        h.shutter_leaf = lambda *a, **k: None
    return h


def wall_backing():
    b = kit.Builder("backing", 99)
    b.box((0, 0.5, 2.0), (8.0, 1.0, 8.0), "plaster", "e0c9a0")
    return b.finish()


def named(ob, name):
    ob.name = name
    ob.data.name = name
    return ob


def window():
    h = house(1, quiet=True)
    h.window(0.0, 0.0, 1.0, 1.4, grate=False)
    return h.fine.finish()


def grate():
    b = kit.Builder("grate", 2)
    for i in range(5):
        b.box((-0.5 + (i + 0.5) / 5, -0.11, 0.7), (0.022, 0.022, 1.4), "iron", IRON)
    for z in (0.12, 1.28):
        b.box((0, -0.11, z), (1.0, 0.022, 0.022), "iron", IRON)
    return b.finish()


def shutter(angle):
    h = house(3 + angle)
    h.shutter_leaf(0.0, 0.0, 0.5, 1.4, -1, angle)
    return h.fine.finish()


def door_arched(leaf):
    h = house(5)
    b, fy = h.fine, h.fy
    dw, dh = 1.25, 2.05
    spring = dh - dw / 2
    radius = dw / 2 + 0.1
    for s in (-1, 1):
        b.box((s * (dw / 2 + 0.1), fy - 0.05, spring / 2), (0.2, 0.1, spring), "stone", "cdc3ae", tint=b.vary(0.05))
    n = 9
    for i in range(n):
        ang = math.pi * (i + 0.5) / n
        big = 1.18 if i == n // 2 else 1.0
        b.box((radius * math.cos(ang), fy - 0.05, spring + radius * math.sin(ang)), (0.25 * big, 0.1, 0.2 * big), "stone",
              "cdc3ae", rot=(0, math.pi / 2 - ang, 0), tint=b.vary(0.07))
    b.box((0, fy - 0.3, 0.06), (dw + 0.5, 0.5, 0.12), "stone", "c4baa6", tint=b.vary(0.05))
    if leaf:
        b.cylinder((0, fy - 0.02, spring), dw / 2, 0.03, "glass", GLASS, rot=(math.pi / 2, 0, 0), segments=16)
        for k in (-1, 0, 1):
            ang = math.pi / 2 + k * 0.55
            b.box((math.cos(ang) * dw / 4, fy - 0.04, spring + math.sin(ang) * dw / 4), (0.02, 0.02, dw / 2), "iron", IRON,
                  rot=(0, math.pi / 2 - ang, 0))
        planks = 5
        for i in range(planks):
            px = -dw / 2 + dw * (i + 0.5) / planks
            b.box((px, fy - 0.035, spring / 2), (dw / planks - 0.012, 0.05, spring), "wood", WOOD_DOOR, tint=b.vary(0.08))
        b.box((0, fy - 0.07, spring - 0.04), (dw, 0.04, 0.08), "wood", WOOD_DOOR)
        b.cylinder((dw * 0.3, fy - 0.08, 1.0), 0.035, 0.03, "metal", "c9a24a", rot=(math.pi / 2, 0, 0))
    return b.finish()


def door_plain():
    h = house(7)
    h.door_plain(0.0)
    return h.fine.finish()


def balcony():
    h = house(9, quiet=True)
    h.balcony(0.0, 0.0)
    return h.fine.finish()


def shopfront(open_door):
    h = house(11)
    b, fy = h.fine, h.fy
    ws = 3.0
    post = 0.68 if open_door else 0.55
    for s in (-1, 1):
        mid = s * (post + ws / 2) / 2
        b.box((mid, fy - 0.02, 1.2), (ws / 2 - post, 0.04, 2.1), "glass", GLASS)
    for x in (-ws / 2, ws / 2, -post, post):
        b.box((x, fy - 0.06, 1.15), (0.12, 0.1, 2.3), "wood", SHOPFRAME)
    b.box((0, fy - 0.06, 2.3), (ws + 0.12, 0.1, 0.12), "wood", SHOPFRAME)
    for s in (-1, 1):
        mid = s * (post + ws / 2) / 2
        b.box((mid, fy - 0.06, 0.25), (ws / 2 - post + 0.12, 0.12, 0.5), "wood", SHOPFRAME)
    if not open_door:
        b.box((0, fy - 0.07, 1.05), (1.0, 0.05, 2.0), "wood", SHOPFRAME)
        b.box((0, fy - 0.1, 1.25), (0.8, 0.02, 1.2), "glass", GLASS)
    b.box((0, fy - 0.06, 2.62), (ws + 0.3, 0.07, 0.44), "paint", "e9dfc7")
    return b.finish()


def chimney_stack():
    b = kit.Builder("chimney_stack", 13)
    b.box((0, 0, 0.5), (0.55, 0.55, 1.0), "brick", BRICK, tint=b.vary(0.06))
    return b.finish()


def chimney_cap():
    b = kit.Builder("chimney_cap", 15)
    for cx in (-0.2, 0.2):
        for cy in (-0.2, 0.2):
            b.box((cx, cy, 0.15), (0.12, 0.12, 0.3), "brick", BRICK, tint=b.vary(0.08))
    b.box((0, 0, 0.33), (0.75, 0.75, 0.06), "stone", "cfc6b4")
    for sgn in (-1, 1):
        b.box((0, sgn * 0.2, 0.43), (0.8, 0.46, 0.05), "roof", TILE, rot=(-sgn * math.radians(28), 0, 0))
    return b.finish()


def coppo(convex):
    b = kit.Builder("coppo", 17)
    b.tile(Matrix.Identity(4), 0.2 if convex else 0.34, 0.44, "roof", TILE, convex=convex)
    return b.finish()


def wall_lamp():
    h = house(19)
    h.wall_lamp(0.0, 0.0)
    return h.fine.finish()


def pot_flowers():
    h = house(21)
    h.fine.cylinder((0, 0, 0.15), 0.17, 0.3, "brick", POT, radius2=0.13, tint=h.fine.vary(0.06))
    h.flowers(0.0, 0.0, 0.36)
    return h.fine.finish()


PARTS = [("window", window, True), ("grate", grate, True), ("door_arched", lambda: door_arched(True), True),
         ("doorway_arched", lambda: door_arched(False), True), ("door_plain", door_plain, True),
         ("balcony", balcony, True), ("shopfront", lambda: shopfront(False), True), ("shopfront_open", lambda: shopfront(True), True), ("chimney_stack", chimney_stack, False),
         ("chimney_cap", chimney_cap, False), ("coppo_cap", lambda: coppo(True), False),
         ("coppo_pan", lambda: coppo(False), False), ("wall_lamp", wall_lamp, True), ("pot_flowers", pot_flowers, False)]
PARTS += [("shutter_%d" % a, lambda a=a: shutter(a), True) for a in SHUTTER_ANGLES]


def main():
    a = kit.args()
    out = a.get("out", "godot/assets/models/kit")
    kit.reset()
    backing = wall_backing()
    objs = []
    for name, make, on_wall in PARTS:
        ob = named(make(), name)
        kit.bake_colors(ob, ao_dist=0.5, ao_strength=0.45, ground=False, occluders=[backing] if on_wall else [])
        objs.append(ob)
    bpy.data.objects.remove(backing, do_unlink=True)
    kit.export_glb(objs, os.path.join(out, "langhe_kit.glb"))
    if a.get("blend"):
        kit.save_blend(os.path.join(a["blend"], "langhe_kit.blend"))


main()
