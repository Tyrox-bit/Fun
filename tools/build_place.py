#!/usr/bin/env python3
"""Builds an importable Roblox Studio place (build/FrequencyZero.rbxlx) from src/.

No Rojo required: open the generated file directly in Roblox Studio (File > Open).
Follows default.project.json and Rojo's file conventions so both workflows produce
the same Explorer tree:

  folder/              -> Folder
  folder/init.luau     -> the folder becomes a ModuleScript (children kept)
  name.server.luau     -> Script
  name.client.luau     -> LocalScript
  name.luau            -> ModuleScript

Usage: python3 tools/build_place.py [output.rbxlx]
"""
import itertools
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "default.project.json"
DEFAULT_OUT = ROOT / "build" / "FrequencyZero.rbxlx"

# Properties that may appear in default.project.json: name -> (xml type, enum map or None)
KNOWN_PROPERTIES = {
    "CameraMode": ("token", {"Classic": 0, "LockFirstPerson": 1}),
    "CharacterWalkSpeed": ("float", None),
    "EnableMouseLockOption": ("bool", None),
    "StreamingEnabled": ("bool", None),
    "Technology": ("token", {"Legacy": 0, "Voxel": 1, "Compatibility": 2, "ShadowMap": 3, "Future": 4}),
    "UseAudioApi": ("token", {"Disabled": 0, "Automatic": 1, "Enabled": 2}),
    "EnableDefaultVoice": ("bool", None),
}

_ids = itertools.count()


def referent() -> str:
    return f"RBX{next(_ids):08X}"


def cdata(text: str) -> str:
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def prop_xml(name: str, value) -> str:
    if name not in KNOWN_PROPERTIES:
        raise SystemExit(f"Unknown property in project file: {name} (add it to KNOWN_PROPERTIES)")
    kind, enum = KNOWN_PROPERTIES[name]
    if kind == "token":
        if value not in enum:
            raise SystemExit(f"Unknown enum value {value!r} for {name}")
        return f'<token name="{name}">{enum[value]}</token>'
    if kind == "bool":
        return f'<bool name="{name}">{"true" if value else "false"}</bool>'
    if kind == "float":
        return f'<float name="{name}">{float(value)}</float>'
    raise SystemExit(f"Unsupported property type {kind}")


class Item:
    def __init__(self, class_name: str, name: str, source: str | None = None, props=None):
        self.class_name = class_name
        self.name = name
        self.source = source
        self.props = props or {}
        self.children: list[Item] = []

    def xml(self, depth: int = 1) -> str:
        pad = "\t" * depth
        lines = [f'{pad}<Item class="{self.class_name}" referent="{referent()}">', f"{pad}\t<Properties>"]
        lines.append(f'{pad}\t\t<string name="Name">{escape(self.name)}</string>')
        if self.source is not None:
            lines.append(f'{pad}\t\t<string name="Source">{cdata(self.source)}</string>')
        for key, value in self.props.items():
            lines.append(f"{pad}\t\t{prop_xml(key, value)}")
        lines.append(f"{pad}\t</Properties>")
        for child in self.children:
            lines.append(child.xml(depth + 1))
        lines.append(f"{pad}</Item>")
        return "\n".join(lines)


def script_class(filename: str):
    if filename.endswith(".server.luau"):
        return "Script", filename[: -len(".server.luau")]
    if filename.endswith(".client.luau"):
        return "LocalScript", filename[: -len(".client.luau")]
    if filename.endswith(".luau"):
        return "ModuleScript", filename[: -len(".luau")]
    return None, None


def from_path(path: Path, name: str | None = None) -> Item:
    if path.is_file():
        class_name, base = script_class(path.name)
        if not class_name:
            raise SystemExit(f"Unsupported file: {path}")
        return Item(class_name, name or base, path.read_text(encoding="utf-8"))
    init = path / "init.luau"
    if init.exists():
        item = Item("ModuleScript", name or path.name, init.read_text(encoding="utf-8"))
    else:
        item = Item("Folder", name or path.name)
    for child in sorted(path.iterdir()):
        if child.name == "init.luau" or child.name.startswith("."):
            continue
        if child.is_file() and not child.name.endswith(".luau"):
            continue
        item.children.append(from_path(child))
    return item


def from_node(name: str, node: dict) -> Item:
    if "$path" in node:
        item = from_path(ROOT / node["$path"], name)
        if "$className" in node and item.class_name == "Folder":
            item.class_name = node["$className"]
    else:
        item = Item(node.get("$className", "Folder"), name)
    item.props.update(node.get("$properties", {}))
    for key, child in node.items():
        if not key.startswith("$"):
            item.children.append(from_node(key, child))
    return item


def count(item: Item, totals: dict) -> None:
    totals[item.class_name] = totals.get(item.class_name, 0) + 1
    for child in item.children:
        count(child, totals)


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    project = json.loads(PROJECT.read_text(encoding="utf-8"))
    tree = project["tree"]
    services = [from_node(key, node) for key, node in tree.items() if not key.startswith("$")]
    body = "\n".join(service.xml() for service in services)
    document = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        "\t<External>null</External>\n\t<External>nil</External>\n"
        f"{body}\n</roblox>\n"
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(document, encoding="utf-8")
    totals: dict = {}
    for service in services:
        count(service, totals)
    summary = ", ".join(f"{v} {k}" for k, v in sorted(totals.items()))
    print(f"wrote {out.relative_to(ROOT) if out.is_relative_to(ROOT) else out}: {summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
