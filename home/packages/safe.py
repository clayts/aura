# Safes in Nautilus: a safe is any folder holding a gocryptfs filesystem (one
# with a gocryptfs.conf). Safes look like padlocked folders, and right-clicking
# a locked one offers Unlock…, which asks for its password and unlocks it at
# /run/media/$USER/Safe/NAME, where Nautilus lists it in its sidebar. Ejecting
# it there locks it again, and removes that folder.

import os

from gi.repository import GLib, GObject, Gio, Nautilus

GOCRYPTFS = "@gocryptfs@"
ZENITY = "@zenity@"
MEDIA = f"/run/media/{GLib.get_user_name()}/Safe"
ICON = "metadata::custom-icon-name"  # where Nautilus keeps a file's own icon


def safe_path(file):
    """The path of the safe file is, or None if it isn't one"""
    if file.get_uri_scheme() != "file" or not file.is_directory():
        return None
    path = file.get_location().get_path()
    return path if os.path.isfile(os.path.join(path, "gocryptfs.conf")) else None


def remove(path):
    """Remove where a safe was unlocked, if it was and it's locked"""
    if path and os.path.dirname(path) == MEDIA:
        try:
            os.rmdir(path)
        except OSError:  # still unlocked
            pass


def unlock(safe, prompt=None):
    name = os.path.basename(safe)
    mount = os.path.join(MEDIA, name)
    os.makedirs(mount, exist_ok=True)
    # Several -extpass options are one command's arguments, not split on spaces
    ask = [ZENITY, "--password", f"--title={prompt or f'Password for {name}'}"]
    process = Gio.Subprocess.new(
        [GOCRYPTFS, "-q", *(f"-extpass={arg}" for arg in ask), "--", safe, mount],
        Gio.SubprocessFlags.STDERR_PIPE,
    )

    def done(_, result):
        error = process.communicate_utf8_finish(result)[2].strip()
        status = process.get_exit_status()
        if status == 0:
            return
        os.rmdir(mount)
        if status == 12:  # wrong (or empty) password
            unlock(safe, f"Wrong password for {name}, try again")
        elif status != 9:  # 9: cancelled
            Gio.Subprocess.new(
                [
                    ZENITY,
                    "--error",
                    "--no-markup",
                    "--title=Safe",
                    f"--text=Couldn't unlock {name}: {error}",
                ],
                Gio.SubprocessFlags.NONE,
            )

    process.communicate_utf8_async(None, None, done)


class Safes(GObject.GObject, Nautilus.MenuProvider, Nautilus.InfoProvider):
    def __init__(self):
        super().__init__()
        # Remove where safes were unlocked once they're ejected, including any
        # ejected while Nautilus wasn't running
        self.monitor = Gio.VolumeMonitor.get()
        self.monitor.connect("mount-removed", lambda _, mount: remove(mount.get_root().get_path()))
        for name in os.listdir(MEDIA) if os.path.isdir(MEDIA) else []:
            remove(os.path.join(MEDIA, name))

    def get_file_items(self, files):
        safe = safe_path(files[0]) if len(files) == 1 else None
        if not safe or os.path.ismount(os.path.join(MEDIA, os.path.basename(safe))):
            return []
        item = Nautilus.MenuItem(name="Safe::Unlock", label="Unlock…")
        item.connect("activate", lambda _: unlock(safe))
        return [item]

    def update_file_info(self, file):
        if not safe_path(file):
            return
        location = file.get_location()
        flags = Gio.FileQueryInfoFlags.NONE
        try:
            if location.query_info(ICON, flags).get_attribute_string(ICON) != "folder-private":
                location.set_attribute_string(ICON, "folder-private", flags)
        except GLib.Error:  # somewhere Nautilus can't keep icons
            pass
