#!/usr/bin/env python3
"""Genera, a partir de la textura de color de Tripo (2048^2), los recursos de recoloreado del jugador:

  player_albedo.jpg   textura de color a 1024^2 (detalle y sombreado originales)
  player_mask_a.png   RGBA = camiseta, short, medias, botines   (pesos suaves por region)
  player_mask_b.png   RGBA = piel, pelo, 0, 0
  player_regions.json luminancia media por region (para conservar el sombreado al recolorear)

La clasificacion se hace por color (HSV) porque el atlas de Tripo agrupa cada prenda en islas
de color bien separadas. Uso:
  python3 tools/make_player_textures.py Color.jpg carpeta_salida
"""
import json
import os
import sys

import numpy as np
from PIL import Image


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def rgb_to_hsv(arr):
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    mx = np.max(arr, axis=-1)
    mn = np.min(arr, axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m & (mx == r), ((g - b) / np.where(m, d, 1)) % 6, 0)
    gc = np.where(m & (mx == g), (b - r) / np.where(m, d, 1) + 2, 0)
    bc = np.where(m & (mx == b), (r - g) / np.where(m, d, 1) + 4, 0)
    h = np.where(mx == r, rc, np.where(mx == g, gc, bc)) * 60.0
    s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0.0)
    return h % 360.0, s, mx


def band(h, lo, hi, soft=10.0):
    """Peso 0..1 de que el matiz h (grados) caiga en [lo, hi] con bordes suaves (admite cruce de 0/360)."""
    if lo <= hi:
        inside = smoothstep(lo - soft, lo, h) * (1.0 - smoothstep(hi, hi + soft, h))
    else:
        inside = np.maximum(smoothstep(lo - soft, lo, h), 1.0 - smoothstep(hi, hi + soft, h))
    return inside


def classify(img):
    arr = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    h, s, v = rgb_to_hsv(arr)
    colorful = smoothstep(0.30, 0.50, s)
    w = {}
    w["jersey"] = band(h, 350, 14, 10) * colorful * smoothstep(0.30, 0.45, v)
    w["shorts"] = band(h, 195, 255, 12) * smoothstep(0.30, 0.50, s) * smoothstep(0.15, 0.30, v)
    w["socks"] = (1.0 - smoothstep(0.12, 0.30, s)) * smoothstep(0.55, 0.72, v)
    w["boots"] = (1.0 - smoothstep(0.17, 0.27, v))
    skin_like = band(h, 12, 38, 6) * smoothstep(0.22, 0.34, s) * (1.0 - smoothstep(0.62, 0.74, s)) * smoothstep(0.55, 0.68, v)
    hair_like = band(h, 8, 42, 8) * smoothstep(0.35, 0.50, s) * smoothstep(0.14, 0.24, v) * (1.0 - smoothstep(0.45, 0.60, v))
    w["skin"] = skin_like
    w["hair"] = hair_like
    total = sum(w.values())
    # Pixeles sin ninguna region reconocida: se reparten como piel (zonas de transicion).
    w["skin"] = w["skin"] + np.clip(1.0 - total, 0.0, 1.0) * 0.5
    total = sum(w.values())
    for k in w:
        w[k] = np.where(total > 1e-4, w[k] / np.maximum(total, 1e-4), 0.0)
    return w, arr


def main(src, outdir):
    os.makedirs(outdir, exist_ok=True)
    img = Image.open(src).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    w, arr = classify(img)
    luma = 0.2126 * arr[..., 0] + 0.7152 * arr[..., 1] + 0.0722 * arr[..., 2]
    means = {}
    for k, wk in w.items():
        den = float(wk.sum())
        means[k] = float((luma * wk).sum() / den) if den > 1.0 else 0.5
    img.save(os.path.join(outdir, "player_albedo.jpg"), quality=90)
    a = np.stack([w["jersey"], w["shorts"], w["socks"], w["boots"]], axis=-1)
    b = np.stack([w["skin"], w["hair"], np.zeros_like(w["skin"]), np.zeros_like(w["skin"])], axis=-1)
    Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(outdir, "player_mask_a.png"))
    Image.fromarray((b * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(outdir, "player_mask_b.png"))
    coverage = {k: float(wk.mean()) for k, wk in w.items()}
    with open(os.path.join(outdir, "player_regions.json"), "w") as f:
        json.dump({"mean_luma": means, "coverage": coverage}, f, indent=2)
    print("luma media por region:", {k: round(v, 3) for k, v in means.items()})
    print("cobertura del atlas:", {k: round(v, 3) for k, v in coverage.items()})


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])
