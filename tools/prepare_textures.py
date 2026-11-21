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

# Variants: name -> (Roblox base material, Poly Haven id, is the base material override)
# Overrides texture every part (and terrain) of that material. The others are assigned to
# specific parts by MapDress.Surfaces (part.MaterialVariant), e.g. the dam's weathered
# concrete or the chapel's stone floor.
VARIANTS = {
    # base material overrides
    "Concrete": ("Concrete", "concrete_wall_003", True),
    "Plaster": ("Plaster", "grey_plaster_02", True),
    "CeramicTiles": ("CeramicTiles", "dirty_tiles", True),
    "Metal": ("Metal", "blue_metal_plate", True),
    "DiamondPlate": ("DiamondPlate", "metal_plate", True),
    "CorrodedMetal": ("CorrodedMetal", "rusty_metal_02", True),
    "Wood": ("Wood", "wood_table_worn", True),
    "WoodPlanks": ("WoodPlanks", "weathered_brown_planks", True),
    "Asphalt": ("Asphalt", "worn_asphalt", True),
    "Cobblestone": ("Cobblestone", "rustic_stone_wall_02", True),
    "Slate": ("Slate", "slate_floor", True),
    "Rock": ("Rock", "rock_face_03", True),
    "Brick": ("Brick", "red_brick_03", True),
    "Fabric": ("Fabric", "rough_linen", True),
    "Carpet": ("Carpet", "dirty_carpet", True),
    "RoofShingles": ("RoofShingles", "roof_slates_02", True),
    "Pebble": ("Pebble", "gravel_floor", True),
    "Pavement": ("Pavement", "concrete_pavement", True),
    "Ground": ("Ground", "forest_ground_04", True),
    "Granite": ("Granite", "lichen_rock", True),
    "Marble": ("Marble", "marble_01", True),
    "Mud": ("Mud", "brown_mud_02", True),
    # surface-specific variants
    "ConcreteFloor": ("Concrete", "concrete_floor_worn_001", False),
    "DamConcrete": ("Concrete", "concrete_wall_008", False),
    "CrackedWall": ("Concrete", "cracked_concrete_wall", False),
    "Ceiling": ("Concrete", "ceiling_interior", False),
    "RoofConcrete": ("Concrete", "concrete_layers_02", False),
    "DoorMetal": ("Metal", "rusty_painted_metal", False),
    "Machine": ("Metal", "green_metal_rust", False),
    "Container": ("CorrodedMetal", "container_side", False),
    "Corrugated": ("CorrodedMetal", "rusty_corrugated_iron", False),
    "Bark": ("Wood", "pine_bark", False),
    "Timber": ("Wood", "rough_wood", False),
    "DarkWood": ("Wood", "dark_wood", False),
    "OldFloor": ("WoodPlanks", "old_wood_floor", False),
    "ChapelFloor": ("Slate", "monastery_stone_floor", False),
    "Rubble": ("Slate", "rubble", False),
    "MineFloor": ("Ground", "rocky_trail", False),
}
PICK = {name: v[1] for name, v in VARIANTS.items()}
# share of the original colour kept in the colour map (0 = pure detail map)
CHROMA = {"CeramicTiles": 0.0, "Metal": 0.0, "Fabric": 0.0, "Carpet": 0.15, "Container": 0.0, "Machine": 0.1, "DoorMetal": 0.1, "Marble": 0.0}
DEFAULT_CHROMA = 0.25
# contrast of the colour map around its mean (1 = as scanned): big repeating stains read as
# a pattern on large walls, so concrete is calmed down
CONTRAST = {"Concrete": 0.55, "Plaster": 0.8, "DamConcrete": 0.75}
# tile size overrides in studs (thin tree trunks, small cracks that would repeat too often)
STUDS = {"Bark": 3.0, "CrackedWall": 8.0, "Machine": 5.0, "Timber": 4.0}
MAPS = {"Diffuse": "diff", "nor_gl": "nor", "Rough": "rough", "AO": "ao", "Metal": "metal"}


def curl(url: str, target: Path) -> None:
    subprocess.run(["curl", "-sf", "--max-time", "60", "-o", str(target), url], check=True)


def download() -> None:
    for material, pid in PICK.items():
        folder = RAW / pid
        if (folder / "diff.jpg").exists():
            continue
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
        studs = STUDS.get(material) or round(min(max(float(dims[0]) / 1000 / 0.28, 3), 16), 1)
        manifest[material] = {
            "base": VARIANTS[material][0],
            "override": VARIANTS[material][2],
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
        "| Variant | Poly Haven texture | Author(s) |",
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
