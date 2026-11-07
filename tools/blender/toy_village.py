import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from langhe_lane import House

TRIM = "e8dcc4"
SHUTTER = "2f4f37"
BASE = dict(trim=TRIM, footing="d6ccb8", shutters="open", grates=False, gf=2.8, gwin=(1.0, 1.35), win=(1.0, 1.4))

HOUSES = [
    ("toy_oxblood", 5.6, 6.0, 2, "8c2e2b", SHUTTER, 51, dict(BASE, quoins=TRIM, arch=False, door="6b4a30", number="3", chimney_x=1.4)),
    ("toy_orange", 7.4, 6.2, 2, "d9692f", SHUTTER, 52, dict(BASE, portico=4, arch=False, door="6b4a30", door_slot=1, chimney_x=-2.0, sag=0.03)),
    ("toy_ochre", 5.0, 6.0, 2, "dca23a", SHUTTER, 53, dict(BASE, balcony=True, door_slot=1, pots=True, chimney_x=1.1)),
    ("toy_red", 6.0, 6.2, 2, "b5352c", SHUTTER, 54, dict(BASE, quoins=TRIM, lamp=True, number="7", chimney_x=-1.5)),
    ("toy_yellow", 5.6, 6.0, 2, "e3b53c", SHUTTER, 55, dict(BASE, shop="ALIMENTARI", awning="2f6b45", chimney_x=1.6)),
]


def lamp_double():
    b = kit.Builder("lamp_double", 61)
    b.cylinder((0, 0, 0.12), 0.16, 0.24, "iron", "26282a", segments=12, radius2=0.12)
    b.cylinder((0, 0, 1.7), 0.05, 3.2, "iron", "26282a", segments=10)
    b.cylinder((0, 0, 3.32), 0.08, 0.1, "iron", "26282a", segments=10)
    for s in (-1, 1):
        b.box((s * 0.28, 0, 3.15), (0.56, 0.04, 0.04), "iron", "26282a")
        b.box((s * 0.28, 0, 3.0), (0.035, 0.035, 0.3), "iron", "26282a", rot=(0, s * 0.9, 0))
        b.cylinder((s * 0.56, 0, 2.95), 0.13, 0.32, "glass", "f3d9a0", segments=6, radius2=0.17)
        b.cylinder((s * 0.56, 0, 3.17), 0.2, 0.1, "iron", "26282a", segments=6, radius2=0.05)
        b.cylinder((s * 0.56, 0, 2.77), 0.09, 0.06, "iron", "26282a", segments=6)
    ob = b.finish()
    kit.bake_colors(ob, ao_dist=0.4, ao_strength=0.4)
    return ob


def cafe_set():
    b = kit.Builder("cafe_set", 62)
    b.cylinder((0, 0, 0.74), 0.38, 0.04, "stone", "ece7dc", segments=20)
    b.cylinder((0, 0, 0.38), 0.035, 0.72, "iron", "26282a", segments=8)
    b.cylinder((0, 0, 0.02), 0.22, 0.04, "iron", "26282a", segments=12)
    for k in range(4):
        a = k * math.pi / 2 + 0.3
        cx, cy = math.cos(a) * 0.62, math.sin(a) * 0.62
        rot = (0, 0, a + math.pi / 2)
        b.box((cx, cy, 0.46), (0.42, 0.4, 0.04), "metal", "2f5a3c", rot=rot)
        bx, by = math.cos(a) * 0.82, math.sin(a) * 0.82
        b.box((bx, by, 0.72), (0.42, 0.04, 0.5), "metal", "2f5a3c", rot=rot)
        for lx in (-0.18, 0.18):
            for ly in (-0.16, 0.16):
                px = cx + math.cos(a + math.pi / 2) * lx + math.cos(a) * ly
                py = cy + math.sin(a + math.pi / 2) * lx + math.sin(a) * ly
                b.box((px, py, 0.22), (0.03, 0.03, 0.46), "metal", "2f5a3c")
    b.cylinder((0.1, -0.05, 0.8), 0.04, 0.08, "glass", "f2efe6", segments=10)
    ob = b.finish()
    kit.bake_colors(ob, ao_dist=0.4, ao_strength=0.5)
    return ob


def paving(name, length, width):
    b = kit.Builder(name, 63)
    b.box((0, 0, 0.03), (length, width, 0.06), "paving", "9a948a", dice=0.6)
    ob = b.finish(bevel=0.02, segments=1)
    kit.bake_colors(ob, ao_strength=0.0, ground=False)
    return ob


def main():
    a = kit.args()
    out = a.get("out", "godot/assets/models/lab")
    only = a.get("only", "")
    jobs = [(name, lambda n=name, w=w, d=d, f=f, wall=wall, sh=sh, seed=seed, o=o: House(n, w, d, f, wall, sh, seed, **o).build())
            for name, w, d, f, wall, sh, seed, o in HOUSES]
    jobs += [("lamp_double", lamp_double), ("cafe_set", cafe_set),
             ("toy_lane", lambda: paving("toy_lane", 22.0, 7.6)), ("toy_piazza", lambda: paving("toy_piazza", 14.0, 10.0))]
    for name, make in jobs:
        if only and name not in only.split(","):
            continue
        kit.reset()
        ob = make()
        kit.export_glb([ob], os.path.join(out, name + ".glb"))
        if a.get("blend"):
            kit.save_blend(os.path.join(a["blend"], name + ".blend"))


main()
