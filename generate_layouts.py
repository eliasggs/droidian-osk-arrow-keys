#!/usr/bin/env python3
"""Regenerate phosh-osk-stub / phosh-osk-stevia layouts and the ESC styling.

Reads every layout embedded in the real keyboard binary, inserts a row with
Left/Up/Down/Right keys at the top of every level, and writes the result to
~/.local/share/phosh-osk-stub/layouts.

The terminal layout's own ESC key is moved out of the second row into that
arrow row: ESC comes first (left of the arrows) and is styled red through the
`esc` style class.  The class is declared in a copy of the keyboard's
common.css in ~/.local/share/phosh-osk-stub/stylesheet, which the wrapper picks
up through G_RESOURCE_OVERLAYS as well.

Works with both names of the keyboard: phosh-osk-stub (resource prefix
/mobi/phosh/osk-stub/, up to 0.47) and phosh-osk-stevia (/mobi/phosh/stevia/,
0.48 and later).  The wrapper at the real binary path makes it read these files
through G_RESOURCE_OVERLAYS.

Run this again after a phosh-osk-stub/stevia package upgrade so the overlay
picks up the new/changed layouts and stylesheet.
"""
import json
import os
import subprocess
import sys

CANDIDATES = [
    "/usr/bin/phosh-osk-stevia.distrib",
    "/usr/bin/phosh-osk-stub.distrib",
    "/usr/bin/phosh-osk-stevia",
    "/usr/bin/phosh-osk-stub",
]
BIN = next((p for p in CANDIDATES if os.path.exists(p)), CANDIDATES[-1])
BASE = os.path.expanduser("~/.local/share/phosh-osk-stub")
OUT = os.path.join(BASE, "layouts")
OUT_STYLESHEET = os.path.join(BASE, "stylesheet")

# Resource prefixes used by the keyboard over time.
RESOURCE_PREFIXES = ("/mobi/phosh/stevia/", "/mobi/phosh/osk-stub/")

ARROWS = [
    ("KEY_LEFT", "\u2190"),
    ("KEY_UP", "\u2191"),
    ("KEY_DOWN", "\u2193"),
    ("KEY_RIGHT", "\u2192"),
]

# Layouts whose ESC key is moved next to the arrows.
ESC_LAYOUTS = {"terminal.json"}

# Appended to the overlaid common.css.  Keep the selectors after the stock
# rules (which is why the block is appended) so they win on equal specificity.
ESC_CSS = """
/* Local change: the terminal layout's ESC key sits left of the arrows and is
 * red (see generate_layouts.py / README). */
pos-key.esc {
  background: #c01c28;
  color: #ffffff;
}

pos-key.esc.pressed {
  background: #99131f;
  color: #f6f5f4;
}
"""


def key_width(key):
    if isinstance(key, str):
        return 2.0 if key == " " else 1.0
    if isinstance(key, list):
        return 1.0
    if isinstance(key, dict):
        return float(key.get("width", 1.0))
    return 1.0


def layer_width(level):
    """Approximate the layer width the way pos-osk-widget.c computes it."""
    rows = level["rows"]
    n = len(rows)
    width = 0.0
    for i, row in enumerate(rows):
        w = sum(key_width(k) for k in row)
        if i == n - 2:
            w += 1.5 + 1.5        # shift + backspace
        elif i == n - 1:
            w += 1.0 + 1.0 + 2.0  # menu + layer toggle + enter
        width = max(width, w)
    return width


def arrow_width(data):
    widths = [layer_width(level) for level in data.get("levels", []) if level.get("rows")]
    if not widths:
        return 1.0
    m = min(widths)
    if m >= 8.0:
        return 2.0
    if m >= 6.0:
        return 1.5
    return 1.0


def arrow_row(width):
    return [{"symbol": symbol, "label": label, "width": width, "style": "sys"}
            for symbol, label in ARROWS]


def esc_key(width):
    return {"symbol": "KEY_ESC", "label": "ESC", "width": width, "style": "esc"}


def strip_esc(data):
    """Drop the layout's own ESC keys so they can be re-added to the arrow row."""
    found = False
    for level in data.get("levels", []):
        for row in level.get("rows") or []:
            keep = [k for k in row
                    if not (isinstance(k, dict) and k.get("symbol") == "KEY_ESC")]
            if len(keep) != len(row):
                found = True
                row[:] = keep
    return found


def extract(resource):
    return subprocess.check_output(["gresource", "extract", BIN, resource])


def resources():
    return subprocess.check_output(["gresource", "list", BIN], text=True).splitlines()


def find_prefix():
    lines = resources()
    for prefix in RESOURCE_PREFIXES:
        if any(line.startswith(prefix + "layouts/") for line in lines):
            return prefix
    raise SystemExit(f"error: no layout resources found in {BIN}")


def list_layouts(prefix):
    out = resources()
    return sorted(
        line.rsplit("/", 1)[1]
        for line in out
        if line.startswith(prefix + "layouts/") and line.endswith(".json")
    )


def write_layouts(prefix):
    names = list_layouts(prefix)
    print(f"{len(names)} layouts")
    for name in names:
        data = json.loads(extract(f"{prefix}layouts/{name}"))
        if name in ESC_LAYOUTS and not strip_esc(data):
            print(f"warning: no ESC key found in {name}", file=sys.stderr)
        width = arrow_width(data)
        for level in data.get("levels", []):
            if level.get("rows"):
                row = arrow_row(width)
                if name in ESC_LAYOUTS:
                    row.insert(0, esc_key(width))
                level["rows"].insert(0, row)
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print(f"written to {OUT}")


def write_stylesheet(prefix):
    css = extract(f"{prefix}stylesheet/common.css").decode("utf-8")
    if "pos-key.esc" not in css:
        css = css.rstrip("\n") + "\n" + ESC_CSS
    path = os.path.join(OUT_STYLESHEET, "common.css")
    with open(path, "w", encoding="utf-8") as f:
        f.write(css)
    print(f"written to {path}")


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(OUT_STYLESHEET, exist_ok=True)
    print(f"binary: {BIN}")
    prefix = find_prefix()
    print(f"resource prefix: {prefix}")
    write_layouts(prefix)
    write_stylesheet(prefix)


if __name__ == "__main__":
    sys.exit(main())
