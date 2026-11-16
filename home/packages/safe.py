# Safes in Nautilus: a safe is any folder holding a gocryptfs filesystem (one
# with a gocryptfs.conf). Safes get a padlock emblem, and right-clicking one
# offers Unlock…, which asks for its password and unlocks it at
# /run/media/$USER/Safe/NAME, where Nautilus lists it in its sidebar, or Lock.
# Ejecting it from the sidebar locks it too, but leaves that folder behind,
# empty, until the safe is next unlocked and locked, or the computer restarts.

import os
import re

from gi.repository import GLib, GObject, Gio, Nautilus

GOCRYPTFS = "@gocryptfs@"
ZENITY = "@zenity@"
FUSERMOUNT = "/run/wrappers/bin/fusermount3"  # NixOS's setuid wrapper
MEDIA = f"/run/media/{GLib.get_user_name()}/Safe"


def safe_path(file):
    """The path of the safe file is, or None if it isn't one"""
    if file.get_uri_scheme() != "file" or not file.is_directory():
        return None
    path = file.get_location().get_path()
    return path if os.path.isfile(os.path.join(path, "gocryptfs.conf")) else None


def mount_of(safe):
    """Where safe is unlocked, or None if it isn't"""
    with open("/proc/self/mounts") as mounts:
        for line in mounts:
            # Mounts' fields escape spaces, tabs, newlines and backslashes
            source, target, kind = (
                re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), field)
                for field in line.split()[:3]
            )
            if kind == "fuse.gocryptfs" and source == safe:
                return target
    return None


def run(argv, done):
    """Run argv without blocking Nautilus, then call done(status, stderr)"""
    process = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDERR_PIPE)
    process.communicate_utf8_async(
        None,
        None,
        lambda _, result: done(
            process.get_exit_status(),
            process.communicate_utf8_finish(result)[2].strip(),
        ),
    )


def error(text):
    Gio.Subprocess.new(
        [ZENITY, "--error", "--no-markup", "--title=Safe", f"--text={text}"],
        Gio.SubprocessFlags.NONE,
    )


def unlock(safe, prompt=None):
    name = os.path.basename(safe)
    prompt = prompt or f"Password for {name}"
    mount = os.path.join(MEDIA, name)
    # gocryptfs would mount over it
    if os.path.ismount(mount):
        return error(f"Another safe called {name} is unlocked")
    os.makedirs(mount, exist_ok=True)

    def done(status, message):
        if status == 0:
            return
        os.rmdir(mount)
        if status == 12:  # wrong (or empty) password
            unlock(safe, f"Wrong password for {name}, try again")
        elif status != 9:  # 9: cancelled
            error(f"Couldn't unlock {name}: {message}")

    # Several -extpass options are one command's arguments, not split on spaces
    ask = [ZENITY, "--password", f"--title={prompt}"]
    run([GOCRYPTFS, "-q", *(f"-extpass={arg}" for arg in ask), "--", safe, mount], done)


def lock(safe, mount):
    def done(status, message):
        if status != 0:
            error(f"Couldn't lock {os.path.basename(safe)}: {message}")
        elif os.path.dirname(mount) == MEDIA:  # not if unlocked elsewhere by hand
            os.rmdir(mount)

    run([FUSERMOUNT, "-u", mount], done)


class Safes(GObject.GObject, Nautilus.MenuProvider, Nautilus.InfoProvider):
    def get_file_items(self, files):
        safe = safe_path(files[0]) if len(files) == 1 else None
        if not safe:
            return []
        mount = mount_of(safe)
        item = Nautilus.MenuItem(
            name="Safe::Lock" if mount else "Safe::Unlock",
            label="Lock" if mount else "Unlock…",
        )
        item.connect("activate", lambda _: lock(safe, mount) if mount else unlock(safe))
        return [item]

    def update_file_info(self, file):
        if safe_path(file):
            file.add_emblem("emblem-readonly")
