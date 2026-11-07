"""A Piedmontese village street surface: a modelling experiment (docs/MODELS.md).

    blender -b --factory-startup -P tools/blender/langhe_street.py -- --out godot/assets/models/lab [--length 22 --width 7.5]

River cobbles (acciottolato) bedded in grit, with two lines of long stone slabs down the middle (the rotaie, laid for
cart wheels, still in many Piedmont towns). Runs along X, centred on the origin.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

COBBLE = "a39a8c"
SLAB = "c2bdb2"
GRIT = "7d7468"


def street(length: float, width: float, seed: int = 5):
    b = kit.Builder("via_selciato", seed)
    rng = b.rng
    b.box((0, 0, 0.015), (length, width, 0.03), "stone", GRIT)
    gauge, slab_w = 1.7, 0.5
    for sgn in (-1, 1):                     # the slab tracks
        x = -length / 2
        while x < length / 2 - 0.1:
            L = min(rng.uniform(0.8, 1.5), length / 2 - x)
            b.box((x + L / 2, sgn * gauge / 2, 0.055), (L - 0.025, slab_w + rng.uniform(-0.03, 0.03), 0.07),
                  "stone", SLAB, rot=(0, rng.uniform(-0.01, 0.01), rng.uniform(-0.008, 0.008)), tint=b.vary(0.06, 0.02))
            x += L
    step = 0.27
    nx, ny = int(length / step), int(width / step)
    for i in range(nx):
        for j in range(ny):
            x = -length / 2 + (i + 0.5) * step + rng.uniform(-0.05, 0.05) + (step / 2 if j % 2 else 0.0)
            y = -width / 2 + (j + 0.5) * step + rng.uniform(-0.05, 0.05)
            if x > length / 2 - 0.1:
                continue
            if any(abs(y - sgn * gauge / 2) < slab_w / 2 + 0.09 for sgn in (-1, 1)):
                continue
            r = rng.uniform(0.1, 0.135)
            b.blob((x, y, 0.035), r, "stone", COBBLE, squash=0.42, jitter=0.18, subdiv=0,
                   tint=b.vary(0.13, 0.05))
    ob = b.finish()
    kit.bake_colors(ob, ao_dist=0.3, ao_strength=0.7, rays=10)
    return ob


def main():
    a = kit.args()
    kit.reset()
    ob = street(float(a.get("length", 22.0)), float(a.get("width", 7.5)))
    kit.export_glb([ob], os.path.join(a.get("out", "godot/assets/models/lab"), "via_selciato.glb"))
    if a.get("blend"):
        kit.save_blend(os.path.join(a["blend"], "via_selciato.blend"))


main()
