import colorsys
import platform
import random
import re
import socket
import subprocess
import sys
import time
from pathlib import Path

from terminaltexteffects.effects.effect_random_sequence import RandomSequence
from terminaltexteffects.effects.effect_slide import Slide
from terminaltexteffects.utils.graphics import Color, Gradient

ANSI_ESCAPE = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")


def visible_length(s: str) -> int:
    return len(ANSI_ESCAPE.sub("", s))


def side_by_side(left: list[list[str]], right: list[list[str]]) -> list[list[str]]:
    """Play two animations side by side, the shorter one starting late so both end together"""
    count = max(len(left), len(right))
    height = max(len(frame) for frame in left + right)

    def pad(frames: list[list[str]]) -> list[list[str]]:
        width = max(visible_length(line) for frame in frames for line in frame)
        frames = [[]] * (count - len(frames)) + frames
        return [
            [
                line + " " * (width - visible_length(line))
                for line in frame + [""] * (height - len(frame))
            ]
            for frame in frames
        ]

    return [[a + b for a, b in zip(l, r)] for l, r in zip(pad(left), pad(right))]


def logo() -> list[list[str]]:
    toilet = ["toilet", "-f", "future", "--", socket.gethostname()]
    effect = RandomSequence(
        subprocess.run(toilet, capture_output=True, text=True, check=True).stdout
    )
    effect.terminal_config.frame_rate = 0
    # Three colours evenly spaced around a random point on the colour wheel
    hue = random.random()
    effect.effect_config.final_gradient_stops = tuple(
        Color(
            "".join(
                f"{int(c * 255):02x}"
                for c in colorsys.hsv_to_rgb((hue + i / 3) % 1, 0.9, 0.95)
            )
        )
        for i in range(3)
    )
    effect.effect_config.final_gradient_direction = Gradient.Direction.DIAGONAL
    effect.effect_config.final_gradient_frames = 12
    return [frame.split("\n") for frame in effect]


def slide(
    lines: list[str], speed: float, stops: tuple[Color, ...], steps: int
) -> list[list[str]]:
    effect = Slide("\n".join(lines))
    effect.terminal_config.frame_rate = 0
    effect.effect_config.movement_speed = speed
    effect.effect_config.final_gradient_stops = stops
    effect.effect_config.final_gradient_steps = steps
    effect.effect_config.final_gradient_frames = 1
    effect.effect_config.final_gradient_direction = Gradient.Direction.HORIZONTAL
    return [[line + " " for line in frame.split("\n")] for frame in effect]


def hardware_name() -> str:
    dmi = Path("/sys/class/dmi/id")
    try:
        parts = [
            (dmi / field).read_text().strip()
            for field in ("sys_vendor", "product_name", "product_version")
        ]
    except OSError:
        parts = []
    return " ".join(filter(None, parts)) or "Unknown"


def info() -> list[str]:
    release = platform.freedesktop_os_release()
    distro = " ".join(filter(None, (release["PRETTY_NAME"], release.get("BUILD_ID"))))
    return [
        "" + hardware_name(),
        "" + distro,
        "" + platform.system() + " " + platform.release(),
    ]


def frames() -> list[list[str]]:
    separator = ["  󰟀 ❯", "  󰏗 ❯", "  󰻀 ❯"]
    return side_by_side(
        side_by_side(
            logo(), slide(separator, 0.04, (Color("333333"), Color("555555")), 1)
        ),
        slide(info(), 2, (Color("cccccc"),), 10),
    )


delay = 1 / 360
for frame in frames():
    start = time.perf_counter()
    sys.stdout.write("\033[2J\033[H" + "\r\n".join(frame))
    sys.stdout.flush()
    time.sleep(max(0.0, delay - (time.perf_counter() - start)))
