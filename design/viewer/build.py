#!/usr/bin/env python3
"""Generate the design-spec viewer (design/viewer/index.html).

Reads the token JSON files (the single source of truth) and injects them
into template.html. Re-run after any change under design/tokens/:

    python3 design/viewer/build.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TOKENS = ROOT.parent / "tokens"
TEMPLATE = ROOT / "template.html"
OUTPUT = ROOT / "index.html"
MARKER = "/*__SPEC_JSON__*/"


def load(name: str):
    return json.loads((TOKENS / name).read_text(encoding="utf-8"))


def main() -> None:
    spec = {
        "primitives": load("primitives.json"),
        "skins": load("skins.json"),
        "accents": load("accents.json"),
    }
    template = TEMPLATE.read_text(encoding="utf-8")
    if MARKER not in template:
        raise SystemExit(f"marker {MARKER} not found in {TEMPLATE}")
    payload = json.dumps(spec, ensure_ascii=False)
    OUTPUT.write_text(template.replace(MARKER, payload), encoding="utf-8")
    print(f"wrote {OUTPUT} (specVersion {spec['primitives']['specVersion']})")


if __name__ == "__main__":
    main()
