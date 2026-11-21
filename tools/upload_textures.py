#!/usr/bin/env python3
"""Uploads assets/textures/*/*.jpg to Roblox via Open Cloud and writes the image ids into
src/ReplicatedStorage/Shared/Assets.luau (Textures). Then rebuild + bake the place.

    ROBLOX_CREATOR_USER_ID=<your user id> python3 tools/upload_textures.py [--only Concrete,Rock]

Needs an Open Cloud API key with the "Assets" API (read + write) for your account. The key
is NOT read from this repository or the command line: in the cloud session it is injected
by the network proxy (saved as a network secret for apis.roblox.com, header x-api-key).
Locally you can export ROBLOX_API_KEY instead.

Already filled ids are kept (re-running only uploads what is missing). Status: written
against the documented Open Cloud Assets API, first real run still pending.
"""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "assets" / "textures"
ASSETS = ROOT / "src" / "ReplicatedStorage" / "Shared" / "Assets.luau"
API = "https://apis.roblox.com"


def curl_json(args: list) -> dict:
    key = os.environ.get("ROBLOX_API_KEY", "injected-by-proxy")
    result = subprocess.run(["curl", "-s", "--max-time", "120", "-H", f"x-api-key: {key}", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"curl failed ({result.returncode}): {result.stderr.strip()}")
    try:
        return json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        raise RuntimeError("unexpected answer: " + result.stdout[:300])


def upload(path: Path, display: str, user_id: str) -> str:
    mime = "image/png" if path.suffix == ".png" else "image/jpeg"
    request = {
        "assetType": "Decal",
        "displayName": display,
        "description": "SILENT RELAY texture - CC0 source: Poly Haven (see CREDITS.md)",
        "creationContext": {"creator": {"userId": str(user_id)}},
    }
    answer = curl_json(["-X", "POST", f"{API}/assets/v1/assets", "--form-string", "request=" + json.dumps(request), "-F", f"fileContent=@{path};type={mime}"])
    operation = answer.get("path") or answer.get("operationId")
    if not operation:
        raise RuntimeError("no operation: " + json.dumps(answer)[:300])
    if not operation.startswith("operations/"):
        operation = "operations/" + operation
    for _ in range(40):
        state = curl_json([f"{API}/assets/v1/{operation}"])
        if state.get("done"):
            response = state.get("response") or {}
            asset_id = response.get("assetId")
            if not asset_id:
                raise RuntimeError("upload finished without asset id: " + json.dumps(state)[:300])
            return str(asset_id)
        time.sleep(2)
    raise RuntimeError("upload did not finish in time")


def image_id_of_decal(decal_id: str) -> str:
    """A decal wraps an image; MaterialVariants need the IMAGE id."""
    location = curl_json([f"{API}/asset-delivery-api/v1/assetId/{decal_id}"]).get("location")
    if not location:
        raise RuntimeError("no delivery location for decal " + decal_id)
    xml = subprocess.run(["curl", "-s", "--max-time", "60", location], capture_output=True, text=True).stdout
    match = re.search(r"\?id=(\d+)", xml)
    if not match:
        raise RuntimeError("no image id in decal " + decal_id)
    return match.group(1)


def read_ids() -> dict:
    text = ASSETS.read_text(encoding="utf-8")
    ids = {}
    for material, body in re.findall(r"^\t\t(\w+) = \{ (color = .*?) \},$", text, re.M):
        ids[material] = dict(re.findall(r'(\w+) = "([^"]*)"', body))
    return ids


def write_id(material: str, map_name: str, value: str) -> None:
    text = ASSETS.read_text(encoding="utf-8")
    pattern = re.compile(r"^(\t\t" + re.escape(material) + r" = \{ .*?" + re.escape(map_name) + r' = ")([^"]*)(")', re.M)
    text, count = pattern.subn(lambda m: m.group(1) + value + m.group(3), text, count=1)
    if count != 1:
        raise RuntimeError(f"could not find {material}.{map_name} in Assets.luau")
    ASSETS.write_text(text, encoding="utf-8")


def read_grime() -> dict:
    text = ASSETS.read_text(encoding="utf-8")
    block = text[text.index("\tGrime = {"):]
    block = block[: block.index("\t},")]
    return dict(re.findall(r'(\w+) = "([^"]*)"', block))


def write_grime(kind: str, value: str) -> None:
    text = ASSETS.read_text(encoding="utf-8")
    start = text.index("\tGrime = {")
    pattern = re.compile(r'(\t\t' + re.escape(kind) + r' = ")([^"]*)(")')
    head, tail = text[:start], text[start:]
    tail, count = pattern.subn(lambda m: m.group(1) + value + m.group(3), tail, count=1)
    if count != 1:
        raise RuntimeError(f"could not find Grime.{kind} in Assets.luau")
    ASSETS.write_text(head + tail, encoding="utf-8")


def main() -> int:
    user_id = os.environ.get("ROBLOX_CREATOR_USER_ID")
    if not user_id or not user_id.isdigit():
        raise SystemExit("set ROBLOX_CREATOR_USER_ID to your numeric Roblox user id")
    only = None
    if len(sys.argv) > 2 and sys.argv[1] == "--only":
        only = set(sys.argv[2].split(","))
    manifest = json.loads((TEXTURES / "manifest.json").read_text())
    ids = read_ids()
    done = 0
    for material, entry in manifest.items():
        if only and material not in only:
            continue
        for map_name in entry["maps"]:
            if ids.get(material, {}).get(map_name):
                continue
            path = TEXTURES / material / f"{map_name}.jpg"
            decal = upload(path, f"SR_{material}_{map_name}", user_id)
            image = image_id_of_decal(decal)
            write_id(material, map_name, f"rbxassetid://{image}")
            done += 1
            print(f"{material}.{map_name}: decal {decal} -> image {image}")
    for kind, current in read_grime().items():
        if current or (only and "Grime" not in only):
            continue
        path = TEXTURES / "Grime" / f"{kind}.png"
        decal = upload(path, f"SR_Grime_{kind}", user_id)
        image = image_id_of_decal(decal)
        write_grime(kind, f"rbxassetid://{image}")
        done += 1
        print(f"Grime.{kind}: decal {decal} -> image {image}")
    print(f"uploaded {done} images")
    return 0


if __name__ == "__main__":
    sys.exit(main())
