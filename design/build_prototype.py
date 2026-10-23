#!/usr/bin/env python3
"""Build prototype/volt-prototype.html from its template.

Injects the exercise details, the movement library and the animation engine into
prototype/src/volt-prototype.template.html, then fills the generated colour tokens.

  python3 design/build_prototype.py
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "prototype" / "src" / "volt-prototype.template.html"
DETAILS = ROOT / "prototype" / "src" / "exercise-details.json"
MOVEMENTS = ROOT / "design" / "movements.json"
ENGINE = ROOT / "design" / "motion" / "volt-motion.js"
OUT = ROOT / "prototype" / "volt-prototype.html"


def compact(path):
    return json.dumps(json.loads(path.read_text()), separators=(",", ":"))


def main():
    html = TEMPLATE.read_text()
    engine = ENGINE.read_text().replace("if (typeof module !== 'undefined') module.exports = VoltMotion;\n", "")
    for marker, value in (("/*__EXDATA__*/", compact(DETAILS)), ("/*__MOVEMENTS__*/", compact(MOVEMENTS)), ("/*__ENGINE__*/", engine)):
        if marker not in html:
            sys.exit(f"{TEMPLATE.relative_to(ROOT)}: missing {marker}")
        html = html.replace(marker, value)
    OUT.write_text(html)
    print(f"Wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")
    subprocess.run([sys.executable, str(ROOT / "design" / "generate_theme.py")], check=True)


if __name__ == "__main__":
    main()
