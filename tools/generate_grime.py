#!/usr/bin/env python3
"""Generates the grime decals (RGBA PNG, transparent background, 100 % original):
water stains running down from ceilings, rust streaks under pipes and fittings, mould in
corners, soot, cracks and scratched tally marks. MapDress.Grime places them on the walls.

    python3 tools/generate_grime.py      -> assets/textures/Grime/<kind>.png
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures" / "Grime"
N = 512
rng = np.random.default_rng(214)


def fbm(n: int, octaves: int = 6, seed: int = 0) -> np.ndarray:
    local = np.random.default_rng(seed)
    out = np.zeros((n, n), np.float32)
    amp = 1.0
    for o in range(octaves):
        size = 2 ** (o + 2)
        grid = local.random((size, size)).astype(np.float32)
        layer = np.asarray(Image.fromarray((grid * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), np.float32) / 255
        out += layer * amp
        amp *= 0.5
    out -= out.min()
    return out / out.max()


def save(name: str, color: tuple, alpha: np.ndarray) -> None:
    a = np.clip(alpha, 0, 1)
    rgba = np.zeros((N, N, 4), np.uint8)
    for i in range(3):
        rgba[..., i] = color[i]
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(OUT / f"{name}.png", optimize=True)
    print(name)


def water_stain() -> None:
    # runs from the top edge downwards, a tide line where it dried
    y = np.linspace(0, 1, N)[:, None]
    x = np.linspace(0, 1, N)[None, :]
    noise = fbm(N, 6, 1)
    streaks = np.zeros((N, N), np.float32)
    for _ in range(14):
        cx = rng.uniform(0.15, 0.85)
        width = rng.uniform(0.01, 0.05)
        length = rng.uniform(0.35, 0.95)
        wobble = (fbm(N, 3, int(rng.integers(1000)))[:, :1] - 0.5) * 0.06
        dx = np.abs(x - cx - wobble)
        streaks = np.maximum(streaks, np.clip(1 - dx / width, 0, 1) * np.clip(1 - y / length, 0, 1) ** 0.6)
    top = np.clip(1 - y / 0.22, 0, 1) * (0.5 + 0.5 * noise)
    tide = np.exp(-((y - 0.2 - (noise - 0.5) * 0.1) ** 2) / 0.0006) * 0.35
    edge = np.clip(1 - np.abs(x - 0.5) / 0.5, 0, 1) ** 0.4
    save("water_stain", (52, 46, 36), (np.maximum(streaks * 0.5, top * 0.55) + tide) * edge * (0.6 + 0.4 * noise))


def rust_streak() -> None:
    y = np.linspace(0, 1, N)[:, None]
    x = np.linspace(0, 1, N)[None, :]
    noise = fbm(N, 6, 2)
    alpha = np.zeros((N, N), np.float32)
    for _ in range(7):
        cx = rng.uniform(0.35, 0.65)
        width = rng.uniform(0.02, 0.07)
        length = rng.uniform(0.4, 1.0)
        alpha = np.maximum(alpha, np.clip(1 - np.abs(x - cx) / width, 0, 1) * np.clip(1 - y / length, 0, 1) ** 1.2)
    source = np.exp(-(((x - 0.5) ** 2) / 0.01 + (y ** 2) / 0.006))
    save("rust_streak", (110, 52, 22), np.clip(alpha * 0.7 + source * 0.8, 0, 1) * (0.55 + 0.45 * noise))


def mould() -> None:
    noise = fbm(N, 7, 3)
    y = np.linspace(0, 1, N)[:, None]
    x = np.linspace(0, 1, N)[None, :]
    corner = np.clip(1 - np.sqrt(x ** 2 + (1 - y) ** 2) / 0.9, 0, 1)
    spots = np.clip((noise - 0.45) * 3, 0, 1)
    save("mould", (24, 30, 20), np.clip(corner * 1.4 * spots + corner ** 3 * 0.4, 0, 0.9))


def soot() -> None:
    noise = fbm(N, 6, 4)
    y = np.linspace(0, 1, N)[:, None]
    x = np.linspace(0, 1, N)[None, :]
    plume = np.clip(1 - np.abs(x - 0.5) / (0.15 + 0.35 * (1 - y)), 0, 1) * np.clip(1.1 - y, 0, 1)
    save("soot", (14, 12, 10), plume ** 1.5 * (0.4 + 0.6 * noise) * 0.85)


def cracks() -> None:
    img = Image.new("L", (N, N), 0)
    draw = ImageDraw.Draw(img)

    def branch(x, y, angle, length, width, depth):
        if depth == 0 or length < 8:
            return
        steps = int(length / 6)
        for _ in range(steps):
            angle += rng.normal(0, 0.35)
            nx, ny = x + np.cos(angle) * 6, y + np.sin(angle) * 6
            draw.line((x, y, nx, ny), fill=255, width=max(1, int(width)))
            x, y = nx, ny
            width *= 0.97
            if rng.random() < 0.06:
                branch(x, y, angle + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), length * 0.5, width * 0.7, depth - 1)

    branch(N * 0.5, 0, np.pi / 2, N * 0.9, 4, 4)
    branch(N * 0.3, N * 0.2, np.pi * 0.4, N * 0.5, 2.5, 3)
    alpha = np.asarray(img.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
    save("cracks", (20, 18, 16), alpha * 0.9)


def tally() -> None:
    # scratched tally marks: groups of four strokes and a slash - someone counted
    img = Image.new("L", (N, N), 0)
    draw = ImageDraw.Draw(img)
    x0, y0 = 40, 60
    for group in range(7):
        gx = x0 + (group % 4) * 110 + rng.integers(-6, 6)
        gy = y0 + (group // 4) * 170 + rng.integers(-6, 6)
        for k in range(4):
            sx = gx + k * 18 + rng.integers(-3, 3)
            draw.line((sx, gy + rng.integers(-4, 4), sx + rng.integers(-6, 6), gy + 110 + rng.integers(-6, 6)), fill=255, width=4)
        draw.line((gx - 10, gy + 90, gx + 80, gy + 20), fill=255, width=4)
    alpha = np.asarray(img.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255
    rough = fbm(N, 5, 6)
    save("tally", (215, 210, 196), alpha * (0.55 + 0.45 * rough))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for fn in (water_stain, rust_streak, mould, soot, cracks, tally):
        fn()
