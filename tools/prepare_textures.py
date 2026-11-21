#!/usr/bin/env python3
"""Downloads CC0 photo-scanned PBR textures from Poly Haven and prepares them for Roblox
MaterialVariants (assets/textures/<Material>/color|normal|roughness[|metalness].jpg).

    python3 tools/prepare_textures.py download   # needs api.polyhaven.com + dl.polyhaven.org
    python3 tools/prepare_textures.py process    # raw -> assets/textures (no network)

Processing (why):
  * ambient occlusion is baked into the colour map (Roblox has no AO slot) -> depth in
    cracks, joints and grout
  * Roblox MULTIPLIES a MaterialVariant's colour map with the part's Color. The maps are
    therefore turned into light "detail" maps (mean brightness 0.78, most of the original
    colour removed) so the colours chosen in the map builders still decide the look
  * real-world size -> StudsPerTile (1 stud ~ 0.28 m), so tiles are tile-sized
  * 1024 x 1024 (Roblox maximum), normal maps in OpenGL convention (what Roblox expects)

All sources are CC0 (public domain) - see assets/textures/CREDITS.md.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"
RAW = Path(os.environ.get("FZ_TEXTURE_RAW", ROOT / "build" / "texture_raw"))

# Roblox base material -> Poly Haven asset id
PICK = {
    "Concrete": "concrete_wall_003",
    "Plaster": "grey_plaster_02",
    "CeramicTiles": "dirty_tiles",
    "Metal": "blue_metal_plate",
    "DiamondPlate": "metal_plate",
    "CorrodedMetal": "rusty_metal_02",
    "Wood": "wood_table_worn",
    "WoodPlanks": "weathered_brown_planks",
    "Asphalt": "worn_asphalt",
    "Cobblestone": "rustic_stone_wall_02",
    "Slate": "slate_floor",
    "Rock": "rock_face_03",
    "Brick": "red_brick_03",
    "Fabric": "rough_linen",
    "Carpet": "dirty_carpet",
    "RoofShingles": "roof_slates_02",
    "Pebble": "gravel_floor",
    "Pavement": "concrete_pavement",
    "Ground": "forest_ground_04",
}
# share of the original colour kept in the colour map (0 = pure detail map)
CHROMA = {"CeramicTiles": 0.0, "Metal": 0.0, "Fabric": 0.0, "Carpet": 0.15}
DEFAULT_CHROMA = 0.25
# contrast of the colour map around its mean (1 = as scanned): big repeating stains read as
# a pattern on large walls, so concrete is calmed down
CONTRAST = {"Concrete": 0.55, "Plaster": 0.8}
MAPS = {"Diffuse": "diff", "nor_gl": "nor", "Rough": "rough", "AO": "ao", "Metal": "metal"}


def curl(url: str, target: Path) -> None:
    subprocess.run(["curl", "-sf", "--max-time", "60", "-o", str(target), url], check=True)


def download() -> None:
    for material, pid in PICK.items():
        folder = RAW / pid
        folder.mkdir(parents=True, exist_ok=True)
        curl(f"https://api.polyhaven.com/files/{pid}", folder / "files.json")
        curl(f"https://api.polyhaven.com/info/{pid}", folder / "info_full.json")
        files = json.loads((folder / "files.json").read_text())
        info = json.loads((folder / "info_full.json").read_text())
        (folder / "info.json").write_text(json.dumps({"authors": info.get("authors"), "name": info.get("name"), "dimensions": info.get("dimensions")}))
        for key, short in MAPS.items():
            entry = files.get(key, {}).get("1k", {}).get("jpg")
            if entry and entry["url"].startswith("https://dl.polyhaven.org/"):
                curl(entry["url"], folder / f"{short}.jpg")
        print("downloaded", material, pid)


def process() -> None:
    import numpy as np
    from PIL import Image

    luma = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for material, pid in PICK.items():
        raw = RAW / pid
        info = json.loads((raw / "info.json").read_text())
        out = OUT / material
        out.mkdir(parents=True, exist_ok=True)
        for old in out.glob("*.jpg"):
            old.unlink()

        def load(name: str, mode: str):
            return Image.open(raw / name).convert(mode).resize((1024, 1024), Image.LANCZOS)

        color = np.asarray(load("diff.jpg", "RGB"), dtype=np.float32) / 255
        if (raw / "ao.jpg").exists():
            ao = np.asarray(load("ao.jpg", "L"), dtype=np.float32) / 255
            color = color * (ao[..., None] ** 0.7)
        lum = (color * luma).sum(-1, keepdims=True)
        color = lum + CHROMA.get(material, DEFAULT_CHROMA) * (color - lum)
        mean = float((color * luma).sum(-1).mean())
        color = np.clip(color * (0.78 / max(mean, 1e-3)), 0, 1)
        k = CONTRAST.get(material, 1.0)
        color = np.clip(0.78 + (color - 0.78) * k, 0, 1)
        Image.fromarray((color * 255 + 0.5).astype(np.uint8)).save(out / "color.jpg", quality=90, optimize=True)
        load("nor.jpg", "RGB").save(out / "normal.jpg", quality=92, optimize=True)
        load("rough.jpg", "L").save(out / "roughness.jpg", quality=90, optimize=True)
        maps = ["color", "normal", "roughness"]
        if (raw / "metal.jpg").exists():
            load("metal.jpg", "L").save(out / "metalness.jpg", quality=90, optimize=True)
            maps.append("metalness")
        dims = info.get("dimensions") or [2000, 2000]
        studs = round(min(max(float(dims[0]) / 1000 / 0.28, 3), 16), 1)
        manifest[material] = {
            "source": pid,
            "name": info.get("name"),
            "authors": sorted((info.get("authors") or {}).keys()),
            "studsPerTile": studs,
            "maps": maps,
        }
        print(f"{material:14s} {pid:24s} {studs:5} studs {maps}")
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    lines = [
        "# Texture credits",
        "",
        "All textures are from [Poly Haven](https://polyhaven.com) and released under **CC0** (public domain):",
        "free for any use, including commercial, no attribution required. Credited anyway, with thanks.",
        "",
        "| Roblox material | Poly Haven texture | Author(s) |",
        "|---|---|---|",
    ]
    for material, entry in manifest.items():
        lines.append(f"| {material} | [{entry['name']}](https://polyhaven.com/a/{entry['source']}) | {', '.join(entry['authors'])} |")
    (OUT / "CREDITS.md").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    step = sys.argv[1] if len(sys.argv) > 1 else "process"
    if step == "download":
        download()
    elif step == "process":
        process()
    else:
        raise SystemExit("usage: prepare_textures.py download|process")
