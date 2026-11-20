#!/usr/bin/env python3
"""Lightweight structural check for Luau files (no Luau toolchain required).

Catches the most common hand-editing mistakes: unbalanced function/if/for/while/do/
repeat ... end/until blocks, and unbalanced (), {}, []. Luau if-expressions
(`x = if a then b else c`) are recognised by their preceding token.
This is NOT a full parser - use Roblox Studio / luau-analyze for real type checking.

Usage: python3 tools/check_luau_blocks.py [paths...]   (default: src/)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

TOKEN = re.compile(
    r"""
    (?P<longcomment>--\[(?P<eq1>=*)\[.*?\](?P=eq1)\])
  | (?P<comment>--[^\n]*)
  | (?P<longstring>\[(?P<eq2>=*)\[.*?\](?P=eq2)\])
  | (?P<string>"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<number>\d[\w.]*)
  | (?P<op>\.\.\.|\.\.=?|==|~=|<=|>=|//=?|::|->|[-+*/%^]=|[-+*/%^#<>=(){}\[\];:,.?|&])
  | (?P<ws>\s+)
  | (?P<other>.)
    """,
    re.S | re.X,
)

EXPR_CONTEXT = {
    "=", "(", ",", "return", "{", "[", "and", "or", "not", "..", "==", "~=", "<", ">",
    "<=", ">=", "+", "-", "*", "/", "//", "%", "^", "#", "+=", "-=", "*=", "/=", "..=",
    "then", "else", "in", ":",
}
PAIRS = {")": "(", "}": "{", "]": "["}


def check(path: Path) -> list:
    text = path.read_text(encoding="utf-8")
    problems = []
    stack = []  # (kind, line)
    brackets = []
    pending_do = 0
    prev = None
    line = 1
    if_expr_depth = []  # bracket depth at which an if-expression started
    for match in TOKEN.finditer(text):
        kind = match.lastgroup
        value = match.group(0)
        start_line = line
        line += value.count("\n")
        if kind in ("ws", "comment", "longcomment"):
            continue
        if kind == "other":
            problems.append(f"{path}:{start_line}: unexpected character {value!r}")
            prev = value
            continue
        token = value if kind in ("name", "op") else "<lit>"
        if kind == "name":
            if token == "if":
                # `then`/`else` only count as expression context inside an if-expression
                expr_ctx = prev in EXPR_CONTEXT and not (prev in ("then", "else") and not if_expr_depth)
                if expr_ctx:
                    if_expr_depth.append(len(brackets))
                else:
                    stack.append(("if", start_line))
            elif token in ("function",):
                stack.append(("function", start_line))
            elif token in ("for", "while"):
                stack.append((token, start_line))
                pending_do += 1
            elif token == "do":
                if pending_do:
                    pending_do -= 1
                else:
                    stack.append(("do", start_line))
            elif token == "repeat":
                stack.append(("repeat", start_line))
            elif token == "end":
                if not stack or stack[-1][0] == "repeat":
                    problems.append(f"{path}:{start_line}: unexpected 'end'")
                else:
                    stack.pop()
            elif token == "until":
                if not stack or stack[-1][0] != "repeat":
                    problems.append(f"{path}:{start_line}: unexpected 'until'")
                else:
                    stack.pop()
        elif kind == "op":
            if token in "({[":
                brackets.append((token, start_line))
            elif token in ")}]":
                if not brackets or brackets[-1][0] != PAIRS[token]:
                    problems.append(f"{path}:{start_line}: unbalanced {token!r}")
                else:
                    brackets.pop()
                while if_expr_depth and if_expr_depth[-1] > len(brackets):
                    if_expr_depth.pop()
            elif token == "," and if_expr_depth and if_expr_depth[-1] == len(brackets):
                if_expr_depth.pop()
        # An if-expression ends at a statement boundary; approximate with line ends at depth 0.
        if if_expr_depth and "\n" in text[match.end():match.end() + 1] and not brackets:
            if token not in ("then", "else", "elseif", "and", "or", "=", ","):
                if_expr_depth.clear()
        prev = token
    for kind, start in stack:
        problems.append(f"{path}:{start}: '{kind}' is never closed")
    for token, start in brackets:
        problems.append(f"{path}:{start}: '{token}' is never closed")
    return problems


def main() -> int:
    targets = [Path(p) for p in sys.argv[1:]] or [ROOT / "src"]
    files = []
    for target in targets:
        files.extend(sorted(target.rglob("*.luau")) if target.is_dir() else [target])
    problems = []
    for file in files:
        problems.extend(check(file))
    print(f"checked {len(files)} Luau files")
    if problems:
        print("\n".join(problems))
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
