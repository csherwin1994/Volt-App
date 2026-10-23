#!/usr/bin/env python3
"""
Write Volt's design tokens into the code.

design/tokens.json is the single source of truth. This script copies its values into:
  - Volt/Theme/AppTheme.swift        (VoltColor and VoltSpacing, between the GENERATED TOKENS markers)
  - prototype/volt-prototype.html    (CSS custom properties, between the GENERATED TOKENS markers)

Usage (from the repo root):
  python3 design/generate_theme.py           # update the files
  python3 design/generate_theme.py --check   # exit 1 if the files are out of date (no changes made)

Only the text between the markers is replaced; everything else in those files is left alone.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "tokens.json"
SWIFT = ROOT / "Volt" / "Theme" / "AppTheme.swift"
PROTOTYPE = ROOT / "prototype" / "volt-prototype.html"

HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


def load_tokens():
    tokens = json.loads(TOKENS.read_text())
    for name, c in tokens["color"].items():
        for mode in ("light", "dark"):
            if not HEX.match(c.get(mode, "")):
                sys.exit(f"tokens.json: color.{name}.{mode} must be a hex colour like #1A2B3C, got {c.get(mode)!r}")
    return tokens


def swift_colors(tokens):
    rows = []
    width = max(len(n) for n in tokens["color"])
    for name, c in tokens["color"].items():
        if c.get("use"):
            rows.append(f"    /// {c['use']}")
        rows.append(
            f'    static let {name.ljust(width)} = Color(light: "{c["light"][1:].upper()}", dark: "{c["dark"][1:].upper()}")'
        )
    return rows


def swift_spacing(tokens):
    values = {**tokens["spacing"], **tokens["radius"]}
    return [f"    static let {name}: CGFloat = {value}" for name, value in values.items()]


def css_tokens(tokens):
    def block(mode, indent):
        pad = " " * indent
        return "\n".join(f"{pad}{c['css']}: {c[mode].upper()};" for c in tokens["color"].values())

    return [
        ":root {",
        block("light", 2),
        "}",
        "@media (prefers-color-scheme: dark) {",
        '  :root:not([data-theme="light"]) {',
        block("dark", 4),
        "  }",
        "}",
        ':root[data-theme="dark"] {',
        block("dark", 2),
        "}",
    ]


def replace_regions(text, regions, begin, end, path):
    """Replace each BEGIN/END marker pair in order with the next list of lines."""
    pattern = re.compile(rf"([ \t]*){re.escape(begin)}\n.*?{re.escape(end)}", re.S)
    matches = list(pattern.finditer(text))
    if len(matches) != len(regions):
        sys.exit(f"{path.relative_to(ROOT)}: expected {len(regions)} '{begin}' markers, found {len(matches)}")
    out, last = [], 0
    for match, lines in zip(matches, regions):
        indent = match.group(1)
        out.append(text[last:match.start()])
        out.append(f"{indent}{begin}\n" + "".join(line + "\n" for line in lines) + f"{indent}{end}")
        last = match.end()
    out.append(text[last:])
    return "".join(out)


def main():
    check = "--check" in sys.argv
    tokens = load_tokens()

    targets = [
        (SWIFT, replace_regions(
            SWIFT.read_text(), [swift_colors(tokens), swift_spacing(tokens)],
            "// BEGIN GENERATED TOKENS", "// END GENERATED TOKENS", SWIFT)),
        (PROTOTYPE, replace_regions(
            PROTOTYPE.read_text(), [css_tokens(tokens)],
            "/* BEGIN GENERATED TOKENS */", "/* END GENERATED TOKENS */", PROTOTYPE)),
    ]

    stale = [path for path, new in targets if path.read_text() != new]
    if check:
        for path in stale:
            print(f"Out of date: {path.relative_to(ROOT)}")
        sys.exit(1 if stale else 0)

    for path, new in targets:
        if path in stale:
            path.write_text(new)
            print(f"Updated {path.relative_to(ROOT)}")
    if not stale:
        print("Already up to date")


if __name__ == "__main__":
    main()
