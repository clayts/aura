import colorsys
import platform
import random
import re
import subprocess
import sys
import time
from pathlib import Path

# from terminaltexteffects.effects.effect_expand import Expand
from terminaltexteffects.effects.effect_random_sequence import RandomSequence
from terminaltexteffects.effects.effect_slide import Slide
from terminaltexteffects.utils.graphics import Color, Gradient


def big_text(text: str) -> list[str]:
    return subprocess.run(
        ["toilet", "-f", "future", "--", text],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split("\n")


def visible_length(s: str) -> int:
    ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
    cleaned = ansi_escape.sub("", s)
    return len(cleaned)


def merge_frames(
    left_frames: list[list[str]], right_frames: list[list[str]]
) -> list[list[str]]:
    if not left_frames and not right_frames:
        return []

    def pad_line(s: str, max_w: int) -> str:
        return s.ljust(max_w)

    def get_dims(frames: list[list[str]]) -> tuple[int, int]:
        max_h = max((len(f) for f in frames))
        max_w = max((visible_length(line) for f in frames for line in f))
        return max_h, max_w

    def make_empty_frame(max_h: int, max_w: int) -> list[str]:
        empty_line = " " * max_w
        return [empty_line] * max_h

    def pad_frames(frames: list[list[str]], max_h: int, max_w: int) -> list[list[str]]:
        empty_line: str = " " * max_w
        return [
            [pad_line(line, max_w) for line in f] + ([empty_line] * (max_h - len(f)))
            for f in frames
        ]

    # Normalize left
    left_h, left_w = get_dims(left_frames)
    left_empty = make_empty_frame(left_h, left_w)
    padded_left = pad_frames(left_frames, left_h, left_w)

    # Normalize right
    right_h, right_w = get_dims(right_frames)
    right_empty = make_empty_frame(right_h, right_w)
    padded_right = pad_frames(right_frames, right_h, right_w)

    # Pad shorter with empty frames at start
    max_frames = max(len(padded_left), len(padded_right))
    num_pad_left = max(0, max_frames - len(padded_left))
    padded_left = [left_empty[:] for _ in range(num_pad_left)] + padded_left

    num_pad_right = max(0, max_frames - len(padded_right))
    padded_right = [right_empty[:] for _ in range(num_pad_right)] + padded_right

    # Merge frames (vertically pad to max height per frame)
    merged_height = max(left_h, right_h)
    left_empty_line: str = " " * left_w
    right_empty_line: str = " " * right_w

    merged: list[list[str]] = []
    for i in range(max_frames):
        frame: list[str] = []
        for j in range(merged_height):
            left_line: str = padded_left[i][j] if j < left_h else left_empty_line
            right_line: str = padded_right[i][j] if j < right_h else right_empty_line
            frame.append(left_line + right_line)
        merged.append(frame)
    return merged


# LOGO #############################################################################################
def rainbow(n: int) -> tuple[Color, ...]:
    base = random.random()
    s, v = 0.9, 0.95
    return tuple(
        Color(f"{int(r * 255):02x}{int(g * 255):02x}{int(b * 255):02x}")
        for r, g, b in (
            colorsys.hsv_to_rgb((base + i / n) % 1.0, s, v) for i in range(n)
        )
    )


def hostname() -> str:
    return subprocess.run(
        ["hostname"], capture_output=True, text=True, check=True
    ).stdout.rstrip("\n")


def logo_keyframe() -> list[str]:
    return big_text(hostname())


def logo() -> list[list[str]]:
    effect = RandomSequence("\n".join(logo_keyframe()))
    effect.terminal_config.frame_rate = 0
    effect.effect_config.starting_color = Color("ffffff")
    # effect.effect_config.movement_speed = 0.25
    effect.effect_config.final_gradient_stops = rainbow(3)
    effect.effect_config.final_gradient_direction = Gradient.Direction.DIAGONAL
    effect.effect_config.final_gradient_frames = 12
    return [frame.split("\n") for frame in effect]


# SEPARATOR ########################################################################################
def separator_keyframe() -> list[str]:
    # ""#""#""#"󰗮"#""#""#"󱄅"#"󰿟"#"󰿠"#"󰆍"#""#""#󰻀#󰏗#
    return [
        "  󰟀 ❯",
        "  󰏗 ❯",
        "  󰻀 ❯",
    ]


# def separator() -> list[list[str]]:
#     effect = RandomSequence("\n".join(separator_keyframe()))
#     effect.terminal_config.frame_rate = 0
#     effect.effect_config.starting_color = Color("000000")
#     # effect.effect_config.movement_speed = 0.25
#     # effect.effect_config.final_gradient_stops = rainbow(3)
#     effect.effect_config.final_gradient_stops = (
#         Color("333333"),
#         Color("555555"),
#     )
#     effect.effect_config.final_gradient_direction = Gradient.Direction.DIAGONAL
#     effect.effect_config.final_gradient_frames = 3
#     return [frame.split("\n") for frame in effect]


def separator() -> list[list[str]]:
    effect = Slide("\n".join(separator_keyframe()))
    effect.effect_config.movement_speed = 0.04
    effect.effect_config.final_gradient_direction = Gradient.Direction.HORIZONTAL
    effect.terminal_config.frame_rate = 0
    effect.effect_config.final_gradient_steps = 1
    effect.effect_config.final_gradient_frames = 1
    effect.effect_config.reverse_direction = False
    effect.effect_config.final_gradient_stops = (
        Color("333333"),
        Color("555555"),
    )
    return [[line + " " for line in frame.split("\n")] for frame in effect]


# INFO #############################################################################################
def hardware_name() -> str:
    # Try dmi fields that together form a usable product string
    base = Path("/sys/class/dmi/id")
    try:
        vendor = (base / "sys_vendor").read_text().strip()
        product = (base / "product_name").read_text().strip()
        version = (base / "product_version").read_text().strip()
        parts = [p for p in (vendor, product, version) if p]
        return " ".join(parts) if parts else "Unknown"
    except Exception:
        return "Unknown"


def distro_name() -> str:
    release = platform.freedesktop_os_release()
    name = release["PRETTY_NAME"]
    if "BUILD_ID" in release:
        name += " " + release["BUILD_ID"]
    # print(release)
    # quit()
    return name


def kernel_name() -> str:
    return platform.system() + " " + platform.release()


def info_keyframe() -> list[str]:
    return [
        "" + hardware_name(),
        "" + distro_name(),
        "" + kernel_name(),
    ]


# def info() -> list[list[str]]:
#     effect = RandomSequence("\n".join(info_keyframe()))
#     effect.terminal_config.frame_rate = 0
#     effect.effect_config.starting_color = Color("ffffff")
#     # effect.effect_config.movement_speed = 0.25
#     # effect.effect_config.final_gradient_stops = rainbow(3)
#     effect.effect_config.final_gradient_stops = (
#         # Color("333333"),
#         Color("cccccc"),
#     )
#     effect.effect_config.final_gradient_direction = Gradient.Direction.VERTICAL
#     effect.effect_config.final_gradient_frames = 3
#     return [frame.split("\n") for frame in effect]


def info() -> list[list[str]]:
    effect = Slide("\n".join(info_keyframe()))
    effect.effect_config.movement_speed = 2
    effect.effect_config.final_gradient_direction = Gradient.Direction.HORIZONTAL
    effect.terminal_config.frame_rate = 0
    effect.effect_config.final_gradient_steps = 10
    effect.effect_config.final_gradient_frames = 1
    effect.effect_config.reverse_direction = False
    effect.effect_config.final_gradient_stops = (
        # Color("333333"),
        Color("cccccc"),
    )
    return [[line + " " for line in frame.split("\n")] for frame in effect]


# def info() -> list[list[str]]:
#     effect = Slide("\n".join(info_keyframe()))
#     effect.terminal_config.frame_rate = 0
#     effect.effect_config.movement_speed = 1
#     effect.effect_config.final_gradient_frames = 2
#     effect.effect_config.final_gradient_stops = (Color("eeeeee"),)
#     effect.effect_config.final_gradient_direction = Gradient.Direction.HORIZONTAL
#     return [frame.split("\n") for frame in effect]


# COMPOSE ##########################################################################################
def frames() -> list[list[str]]:
    return merge_frames(merge_frames(logo(), separator()), info())


# PLAY #############################################################################################
def play(fps: int) -> None:
    if fps <= 0:
        delay = 0.0
    else:
        delay = 1.0 / fps

    # Play animation
    for frame in frames():
        start_time = time.perf_counter()
        content = "\033[2J\033[H" + "\r\n".join(frame)
        _ = sys.stdout.write(content)
        _ = sys.stdout.flush()
        elapsed = time.perf_counter() - start_time
        sleep_time = max(0.0, delay - elapsed)
        time.sleep(sleep_time)


# MAIN #############################################################################################
play(360)
