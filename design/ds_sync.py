#!/usr/bin/env python3
"""
Convert Volt's tokens between the repo and the "Volt Design System" artifact.

  python3 design/ds_sync.py export <dir>
      Write <dir>/tokens.json and <dir>/tokens.css in the Design System artifact's format,
      from design/tokens.json. (Used to publish the repo's tokens to the artifact.)

  python3 design/ds_sync.py import <artifact tokens.json>
      Copy colour, spacing, radius and type values edited in the artifact back into
      design/tokens.json, print what changed, then run generate_theme.py so the Swift code
      and the prototype pick them up.

Token names are the same everywhere: `surfaceHigh` in the artifact is `VoltColor.surfaceHigh` in Swift.
"""
import json
import re
import subprocess
import sys
from collections import OrderedDict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO_TOKENS = ROOT / "design" / "tokens.json"

SANS = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro", system-ui, sans-serif'
LINE_HEIGHTS = {"display": 52, "largeTitle": 40, "title": 28, "body": 22, "callout": 20, "sectionTitle": 18, "caption": 16, "number": 20}
WEIGHTS = {"light": 300, "regular": 400, "medium": 500, "semibold": 600, "bold": 700}
WEIGHT_NAMES = {v: k for k, v in WEIGHTS.items()}
SPACING_USE = {
    "xs": "Gap between an icon and its label.",
    "sm": "Gap inside compact groups (tags, chips).",
    "md": "Card padding; gap between related controls.",
    "lg": "Padding around empty states.",
    "xl": "Large empty-state padding.",
    "xxl": "Bottom padding under a scrolling screen.",
    "gutter": "Left and right screen margin on every tab.",
}
RADIUS_USE = {
    "radiusXs": "Weight and reps input fields.",
    "radiusSm": "The set tick and other small square controls. Buttons are capsules, not this.",
    "radius": "The set table, sheets and any surface that must be set apart.",
    "radiusLg": "The floating rest timer.",
}


def load_repo():
    return json.loads(REPO_TOKENS.read_text(), object_pairs_hook=OrderedDict)


def to_design_system(repo):
    colors = [
        {"name": name, "value": {"light": c["light"].lower(), "dark": c["dark"].lower()}, "usage": c["use"]}
        for name, c in repo["color"].items()
    ]
    styles = []
    for name, s in repo["type"].items():
        if name.startswith("$"):
            continue
        styles.append({
            "name": name,
            "fontSize": f'{s["size"]}px',
            "lineHeight": f'{LINE_HEIGHTS.get(name, round(s["size"] * 1.35))}px',
            "fontWeight": WEIGHTS[s["weight"]],
            "usage": s["use"],
        })
    return OrderedDict([
        ("name", "Volt"),
        ("version", 1),
        ("color", {"themes": [{"id": "light", "name": "Light"}, {"id": "dark", "name": "Dark"}], "tokens": colors}),
        ("type", {
            "fonts": [],
            "families": {"sans": SANS},
            "groups": [{"name": "Text", "family": "sans", "styles": styles}],
        }),
        ("spacing", {"tokens": [{"name": k, "value": f"{v}px", "usage": SPACING_USE.get(k, "")} for k, v in repo["spacing"].items()]}),
        ("radius", {"tokens": [{"name": k, "value": f"{v}px", "usage": RADIUS_USE.get(k, "")} for k, v in repo["radius"].items()]}),
        ("meta", {
            "source": "github",
            "repo": "csherwin1994/Workout-App",
            "paths": {"tokens": ["design/tokens.json", "Volt/Theme/AppTheme.swift"]},
            "synced": date.today().isoformat(),
        }),
    ])


def to_css(ds, title="Volt"):
    lines = [f"/* {title} — generated from tokens.json */"]
    for i, theme in enumerate(ds["color"]["themes"]):
        sel = f':root, [data-theme="{theme["id"]}"]' if i == 0 else f'[data-theme="{theme["id"]}"]'
        lines.append(sel + " {")
        lines += [f'  --{t["name"]}: {t["value"][theme["id"]]};' for t in ds["color"]["tokens"]]
        lines.append("}")
    lines.append(":root {")
    lines += [f'  --{t["name"]}: {t["value"]};' for t in ds["spacing"]["tokens"] + ds["radius"]["tokens"]]
    lines += [f"  --font-{k}: {v};" for k, v in ds["type"]["families"].items()]
    lines.append("}")
    for g in ds["type"]["groups"]:
        for s in g["styles"]:
            lines.append(
                f'.{s["name"]} {{ font-family: var(--font-{g["family"]}); font-size: {s["fontSize"]}; '
                f'line-height: {s["lineHeight"]}; font-weight: {s["fontWeight"]}; }}'
            )
    return "\n".join(lines) + "\n"


def px(value):
    m = re.fullmatch(r"\s*(\d+(?:\.\d+)?)(px)?\s*", str(value))
    if not m:
        raise ValueError(f"expected a px length, got {value!r}")
    n = float(m.group(1))
    return int(n) if n.is_integer() else n


def hex6(value, token):
    v = str(value).strip()
    if re.fullmatch(r"#[0-9a-fA-F]{3}", v):
        v = "#" + "".join(ch * 2 for ch in v[1:])
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", v):
        raise ValueError(f"color {token}: only #rrggbb values can go into the Swift code, got {value!r}")
    return v.upper()


def import_design_system(path):
    ds = json.loads(Path(path).read_text())
    repo = load_repo()
    changes, skipped = [], []

    by_name = {t["name"]: t for t in ds.get("color", {}).get("tokens", [])}
    for name, c in repo["color"].items():
        t = by_name.pop(name, None)
        if t is None:
            skipped.append(f"color {name}: missing in the artifact, kept as is")
            continue
        value = t["value"] if isinstance(t["value"], dict) else {"light": t["value"]}
        for mode in ("light", "dark"):
            if mode not in value:
                continue
            new = hex6(value[mode], name)
            if new != c[mode].upper():
                changes.append(f"color {name} ({mode}): {c[mode]} → {new}")
                c[mode] = new
    for name in by_name:
        skipped.append(f"color {name}: new in the artifact; add it to design/tokens.json by hand if the app should use it")

    for family in ("spacing", "radius"):
        by_name = {t["name"]: t for t in ds.get(family, {}).get("tokens", [])}
        for name, old in repo[family].items():
            if name in by_name:
                new = px(by_name[name]["value"])
                if new != old:
                    changes.append(f"{family} {name}: {old} → {new}")
                    repo[family][name] = new

    styles = {s["name"]: s for g in ds.get("type", {}).get("groups", []) for s in g.get("styles", [])}
    for name, s in repo["type"].items():
        if name.startswith("$") or name not in styles:
            continue
        new_size = px(styles[name]["fontSize"])
        new_weight = WEIGHT_NAMES.get(int(styles[name].get("fontWeight", WEIGHTS[s["weight"]])), s["weight"])
        if new_size != s["size"] or new_weight != s["weight"]:
            changes.append(f'type {name}: {s["size"]}pt {s["weight"]} → {new_size}pt {new_weight}')
            s["size"], s["weight"] = new_size, new_weight

    for line in changes or ["No changes"]:
        print(line)
    for line in skipped:
        print("Skipped:", line)
    if changes:
        REPO_TOKENS.write_text(json.dumps(repo, indent=2, ensure_ascii=False) + "\n")
        subprocess.run([sys.executable, str(ROOT / "design" / "generate_theme.py")], check=True)
        if any(c.startswith("type ") for c in changes):
            print("Note: type sizes are recorded in design/tokens.json; Swift views set their own font sizes, so update those views too.")


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("export", "import"):
        sys.exit(__doc__)
    if sys.argv[1] == "export":
        out = Path(sys.argv[2])
        out.mkdir(parents=True, exist_ok=True)
        ds = to_design_system(load_repo())
        (out / "tokens.json").write_text(json.dumps(ds, indent=2, ensure_ascii=False) + "\n")
        (out / "tokens.css").write_text(to_css(ds))
        print(f"Wrote {out / 'tokens.json'} and {out / 'tokens.css'}")
    else:
        import_design_system(sys.argv[2])


if __name__ == "__main__":
    main()
