import argparse
import io
import json
import os
import urllib.request

from PIL import Image, ImageOps, ImageStat

SET = {
    "plaster": ("white_stucco", True, 4.5),
    "stone": ("white_stucco_02", True, 2.2),
    "paving": ("grey_stone_path", False, 1.0),
    "wood": ("green_rough_planks", True, 1.0),
    "clay": ("clay_plaster", True, 2.0),
    "knit": ("knitted_fleece", True, 2.0),
    "denim": ("denim_fabric", True, 1.0),
    "leather": ("fabric_leather_02", True, 1.2),
    "wool": ("curly_teddy_natural", True, 1.5),
}
MAPS = {"albedo": "Diffuse", "normal": "nor_gl", "rough": "Rough"}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "wonderhaven-texture-fetch"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def neutral(im: Image.Image, contrast: float) -> Image.Image:
    grey = ImageOps.grayscale(im)
    mean = ImageStat.Stat(grey).mean[0]
    return grey.point(lambda v: max(0, min(255, int(0.82 * 255 + (v - mean) * contrast)))).convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="godot/assets/textures/lab/cc0")
    ap.add_argument("--size", type=int, default=1024)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    credits = {}
    for name, (asset, tint, contrast) in SET.items():
        files = json.loads(fetch(f"https://api.polyhaven.com/files/{asset}"))
        for kind, key in MAPS.items():
            url = files[key]["1k"]["jpg"]["url"]
            im = Image.open(io.BytesIO(fetch(url))).convert("RGB").resize((a.size, a.size), Image.LANCZOS)
            if kind == "albedo" and tint:
                im = neutral(im, contrast)
            if kind == "rough":
                im = ImageOps.grayscale(im).convert("RGB")
            im.save(os.path.join(a.out, f"{name}_{kind}.jpg"), quality=90)
        credits[name] = f"https://polyhaven.com/a/{asset}"
        print(name, asset)
    with open(os.path.join(a.out, "SOURCES.json"), "w") as f:
        json.dump({"license": "CC0 1.0 (Poly Haven)", "textures": credits}, f, indent=1)


if __name__ == "__main__":
    main()
