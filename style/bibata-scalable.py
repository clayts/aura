"""Writes SVG cursors for a Bibata theme, in the cursors_scalable layout GNOME
Shell 51 reads: cursors_scalable/<name>/metadata.json plus the SVGs it lists.
Everything comes from Bibata's own sources: the SVGs, their colours from
render.json, and each cursor's hotspot, frame delay and names from the build
config ctgen uses for the X11 cursors

Usage: bibata-scalable.py <bibata source> <theme name> <output directory>
"""

import json
import os
import sys
import tomllib
from pathlib import Path

# The SVGs are drawn on a 256px canvas, the size the X11 cursors are rendered
# from, so the build config's hotspots are already in SVG pixels, and a cursor
# of size 24 shows the whole canvas at 24px, as the X11 cursors do
CANVAS = 256

# Names GNOME asks for that no Bibata cursor goes by, and the cursor to use
EXTRA_NAMES = {"all-resize": "move"}

src, theme, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
render = json.loads((src / "render.json").read_text())[theme]
config_dir = "right" if theme.endswith("-Right") else "normal"
config = tomllib.loads((src / "configs" / config_dir / "x.build.toml").read_text())
cursors = config["cursors"]
defaults = cursors.pop("fallback_settings")


def recolour(svg: str) -> str:
    for colour in render["colors"]:
        for match in (colour["match"].upper(), colour["match"].lower()):
            svg = svg.replace(match, colour["replace"])
    return svg


svg_dir = src / render["dir"]
names = {}
for cursor in cursors.values():
    name = cursor["x11_name"]
    stem = cursor["png"].removesuffix(".png")
    # An animated cursor's png is a pattern, e.g. "wait-*", whose frames are
    # the SVGs in a directory of the cursor's name
    if stem.endswith("-*"):
        frames = sorted((svg_dir / stem.removesuffix("-*")).glob("*.svg"))
    else:
        frames = [svg_dir / f"{stem}.svg"]
    directory = out / name
    directory.mkdir(parents=True)
    metadata = []
    for frame in frames:
        (directory / frame.name).write_text(recolour(frame.read_text()))
        metadata.append(
            {
                "filename": frame.name,
                "hotspot_x": cursor.get("x_hotspot", defaults["x_hotspot"]),
                "hotspot_y": cursor.get("y_hotspot", defaults["y_hotspot"]),
                "nominal_size": CANVAS,
            }
            | (
                {"delay": cursor.get("x11_delay", defaults["x11_delay"])}
                if len(frames) > 1
                else {}
            )
        )
    (directory / "metadata.json").write_text(json.dumps(metadata, indent=2))
    names[name] = name
    for alias in cursor.get("x11_symlinks", []):
        names.setdefault(alias, name)

for alias, name in EXTRA_NAMES.items():
    names.setdefault(alias, names[name])

for alias, name in names.items():
    if alias != name:
        os.symlink(name, out / alias)
