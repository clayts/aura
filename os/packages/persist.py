import grp
import os
import pwd
import stat
import subprocess
from pathlib import Path


def select_paths(src: Path) -> list[Path]:
    """Let the user pick files and folders under `src` with fzf."""
    listing = subprocess.run(
        ["find", ".", "-xdev", "-mindepth", "1", "-printf", "%P\\n"],
        cwd=src,
        stdout=subprocess.PIPE,
        text=True,
        check=False,
    ).stdout
    fzf = subprocess.run(
        [
            "fzf",
            "--multi",
            "--layout=reverse-list",
            f"--preview=cd {src}; grc --colour=on stat {{}}",
        ],
        input=listing,
        stdout=subprocess.PIPE,
        text=True,
        check=False,
    )
    if fzf.returncode not in (0, 1, 130):  # 1 = no match, 130 = aborted
        raise RuntimeError(f"fzf exited with code {fzf.returncode}")
    return [src / line for line in fzf.stdout.splitlines()]


def make_nix(src: Path, paths: list[Path]) -> str:
    # Group by owner (None for the system, else the user whose home it is in)
    groups: dict[str | None, dict[str, list[Path]]] = {}
    for p in paths:
        parts = p.relative_to(src).parts
        user = parts[1] if parts[0] == "home" and len(parts) > 2 else None
        kind = "directories" if p.is_dir() else "files"
        groups.setdefault(user, {}).setdefault(kind, []).append(p)

    lines: list[str] = []
    for user in sorted(groups, key=lambda u: (u is not None, u or "")):
        indent = "" if user is None else "  "
        if user is not None:
            lines.append(f'users."{user}" = {{')
        for kind in ("directories", "files"):
            if kind in groups[user]:
                lines.append(f"{indent}{kind} = [")
                for p in groups[user][kind]:
                    lines.append(f"{indent}  {make_nix_path(src, p, user)}")
                lines.append(f"{indent}];")
        if user is not None:
            lines.append("};")
    return "".join(line + "\n" for line in lines)


def make_nix_path(src: Path, path: Path, user: str | None = None) -> str:
    is_root = user is None
    expected_user = "root" if is_root else user
    expected_group = "root" if is_root else "users"
    expected_mode = "0755"

    is_dir = path.is_dir()
    rel = path.relative_to(src)
    nix = ("/" + str(rel)) if is_root else str(Path(*rel.parts[2:]))

    # Files directly inside a home dir (home/<user>/<file>) skip parent-dir
    # permission checks; home dirs are managed separately.
    directly_in_home = not is_dir and not is_root and len(rel.parts) == 3
    if directly_in_home:
        return f'"{nix}"'

    st = os.stat(path if is_dir else path.parent)
    checks = {
        "user": (pwd.getpwuid(st.st_uid).pw_name, expected_user),
        "group": (grp.getgrgid(st.st_gid).gr_name, expected_group),
        "mode": (f"{stat.S_IMODE(st.st_mode):04o}", expected_mode),
    }
    mismatches = {
        field: actual
        for field, (actual, expected) in checks.items()
        if actual != expected
    }

    if not mismatches:
        return f'"{nix}"'

    attrs = "; ".join(f'{k} = "{v}"' for k, v in mismatches.items())

    if is_dir:
        return f'{{ directory = "{nix}"; {attrs}; }}'
    else:
        return f'{{ file = "{nix}"; parentDirectory = {{ {attrs}; }}; }}'


def filter_paths(paths: list[Path]) -> list[Path]:
    """Drop any path that is inside another selected path."""
    kept: list[Path] = []
    for candidate in sorted(paths):  # parents sort before their children
        if not any(candidate.is_relative_to(keeper) for keeper in kept):
            kept.append(candidate)
    return kept


def main() -> None:

    src = Path("/")

    selected = select_paths(src)

    print(f"Selected {len(selected)} paths")

    filtered = filter_paths(selected)

    if len(filtered) != len(selected):
        print(f"Skipping {len(selected) - len(filtered)} duplicates")

    print()
    print("Nix:")
    print(make_nix(src, filtered))


if __name__ == "__main__":
    main()
