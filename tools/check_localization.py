#!/usr/bin/env python3
"""Offline check for FREQUENCY ZERO language tables.

Verifies that every language has exactly the keys of the English reference, that
{placeholders} match, that no value is empty, and that every localization key used in
the Luau sources exists. Exit code 1 on any problem, so it can run in CI.

Usage: python3 tools/check_localization.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANG_DIR = ROOT / "src/ReplicatedStorage/Shared/Localization/Languages"
SRC_DIR = ROOT / "src"
REFERENCE = "en"

ENTRY = re.compile(r'^\s*([A-Z][A-Z0-9_]*)\s*=\s*"((?:[^"\\]|\\.)*)"\s*,\s*$')
PLACEHOLDER = re.compile(r"{([A-Za-z0-9_]+)}")
# Keys referenced from code: string literals that look like our key format.
KEY_USE = re.compile(r'"((?:MENU|LANG|LOBBY|CHAPTER|SETTINGS|VALUE|EXTRAS|CODE|ADMIN|TOUCH|INTERACT|OBJECT|OBJECTIVE|SPEAKER|SFX|RADIO|FAX|DOC|SIGN|NOTE|ERROR|PAUSE|DATE|ITEM|HUD|SHOP|MIC|VOICE|DOOR|REWARD|MODE|PLAY|MAP|SV|CONTENT|LEADERBOARD|SESSION|UPDATES|UPD|DECISION|SYS|FORECAST|CCTV|AREA|CAL|HINT|CONTROL|PAD|INV)_[A-Z0-9_]+)"')


STRUCTURAL = re.compile(r"^\s*(--.*)?$|^return \{\s*$|^\}\s*$")


def load(path: Path) -> dict:
    table = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = ENTRY.match(line)
        if not match:
            if not STRUCTURAL.match(line):
                # e.g. an unescaped " inside a value would break the whole language file
                raise SystemExit(f"{path.name}:{number}: malformed line: {line.strip()[:80]}")
            continue
        key, value = match.groups()
        if key in table:
            raise SystemExit(f"{path.name}:{number}: duplicate key {key}")
        table[key] = value
    return table


def main() -> int:
    problems = []
    tables = {p.stem: load(p) for p in sorted(LANG_DIR.glob("*.luau"))}
    reference = tables.get(REFERENCE)
    if not reference:
        print("reference language missing")
        return 1

    for lang, table in tables.items():
        for key, value in table.items():
            if not value.strip():
                problems.append(f"{lang}: empty value for {key}")
        if lang == REFERENCE:
            continue
        for key, value in reference.items():
            if key not in table:
                problems.append(f"{lang}: missing {key}")
            elif sorted(PLACEHOLDER.findall(value)) != sorted(PLACEHOLDER.findall(table[key])):
                problems.append(f"{lang}: placeholder mismatch in {key}")
        for key in table:
            if key not in reference:
                problems.append(f"{lang}: extra key {key}")

    used = set()
    for path in SRC_DIR.rglob("*.luau"):
        if LANG_DIR in path.parents:
            continue
        for key in KEY_USE.findall(path.read_text(encoding="utf-8")):
            used.add((key, path.relative_to(ROOT)))
    dynamic_prefixes = ("CHAPTER_0", "SV_EV_", "RADIO_C1_POWER_NO_", "AREA_", "SV_FORECAST_", "FORECAST_BLACKOUT_", "OBJECT_BREAKER_", "CONTROL_DEVICE_", "SYS_")  # built at runtime
    for key, path in sorted(used):
        if key not in reference and not key.startswith(dynamic_prefixes):
            problems.append(f"{path}: uses unknown key {key}")
    for number in range(1, 5):
        if f"CHAPTER_0{number}_TITLE" not in reference:
            problems.append(f"missing CHAPTER_0{number}_TITLE")

    used_keys = {k for k, _ in used}
    unused = sorted(k for k in reference if k not in used_keys and not k.startswith(dynamic_prefixes))
    if unused:
        print(f"not referenced in code ({len(unused)}): {', '.join(unused)}")
    longest = max(tables, key=lambda l: sum(len(v) for v in tables[l].values()))
    print(f"languages: {', '.join(tables)} | keys: {len(reference)} | keys used in code: {len({k for k, _ in used})}")
    print(f"longest language overall (watch UI overflow): {longest}")
    if problems:
        print("\n".join(problems))
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
