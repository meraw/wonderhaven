#!/usr/bin/env python3
"""measure_views.py <dir> [<dir2> ...]: for each view rendered by views.sh, the 3D area's mean luminance (lum),
contrast (spread of luminance), mean saturation, share of clipped white pixels, and the 10th-90th percentile of
luminance, side by side for each folder. The HUD is masked out (clock, tutorial card, key hints). Needs Pillow and
numpy. Keep lum within a few percent of the old views unless a change means to brighten or darken."""
import sys, os
import numpy as np
from PIL import Image

def stats(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
    h, w, _ = im.shape
    m = np.ones((h, w), bool)
    m[:60, :] = False            # clock
    m[60:200, :400] = False      # tutorial card
    m[h - 60:, :500] = False     # key hints
    px = im[m]
    lum = 0.2126 * px[:, 0] + 0.7152 * px[:, 1] + 0.0722 * px[:, 2]
    mx = px.max(1); mn = px.min(1)
    sat = np.where(mx > 0.02, (mx - mn) / np.maximum(mx, 1e-4), 0)
    return {
        "lum": lum.mean(), "contrast": lum.std(), "clip": (mx > 0.985).mean() * 100,
        "dark": (lum < 0.08).mean() * 100, "sat": sat.mean(),
        "p10": np.percentile(lum, 10), "p90": np.percentile(lum, 90),
    }

dirs = sys.argv[1:]
names = sorted(f for f in os.listdir(dirs[0]) if f.endswith(".png"))
hdr = "%-22s" % "view" + "".join("  %-44s" % os.path.basename(d.rstrip("/")) for d in dirs)
print(hdr)
for n in names:
    row = "%-22s" % n[:-4]
    for d in dirs:
        p = os.path.join(d, n)
        if not os.path.exists(p): row += "  %-44s" % "-"; continue
        s = stats(p)
        row += "  lum %.3f con %.3f sat %.3f clip %4.1f%% p10-90 %.2f-%.2f" % (s["lum"], s["contrast"], s["sat"], s["clip"], s["p10"], s["p90"])
    print(row)
