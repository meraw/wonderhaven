import sys

import numpy as np
from PIL import Image

CONTRAST = 0.55
MEAN_SRGB = 0.818
SOURCE = "godot/assets/textures/lab/blender/paving_albedo.jpg"
TARGET = "godot/assets/textures/materials/paving_albedo.jpg"


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def tame(src, dst):
    rgb = to_linear(np.asarray(Image.open(src).convert("RGB")).astype(np.float64) / 255.0)
    rgb = rgb / rgb.reshape(-1, 3).mean(0)
    lum = np.maximum(rgb.mean(2, keepdims=True), 1e-4)
    rgb = rgb * np.power(lum, CONTRAST - 1.0)
    rgb = rgb / rgb.mean() * to_linear(MEAN_SRGB)
    out = to_srgb(np.clip(rgb, 0.0, 1.0))
    Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)).save(dst, quality=90)
    print(f"{dst}: mean {out.mean():.3f}, 1-99% {np.percentile(out, 1):.2f}..{np.percentile(out, 99):.2f}")


if __name__ == "__main__":
    tame(sys.argv[1] if len(sys.argv) > 1 else SOURCE, sys.argv[2] if len(sys.argv) > 2 else TARGET)
