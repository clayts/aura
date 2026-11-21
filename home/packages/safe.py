#!@python3@
# safe: encrypted folders ("safes"), from Nautilus or a terminal, using gocryptfs.
#
# A safe is any folder holding a gocryptfs filesystem (one with a
# gocryptfs.conf). One called NAME is unlocked at
# /run/media/$USER/Safe/HASH/NAME, HASH being a hash of its path, which Nautilus
# lists in its sidebar as NAME, and where ejecting it locks it again.
#
# As a Nautilus extension, this shows safes as padlocked folders, and its
# right-click menus offer New Encrypted Folder… in a folder, and Unlock
# Encrypted Folder… on a locked safe, asking for passwords in dialogs. As the
# safe command:
#
#   safe create DIR    make a new safe at DIR
#   safe unlock DIR    unlock it, printing where
#   safe lock DIR      lock it again
#
# where gocryptfs asks for passwords itself.

import glob
import hashlib
import os
import pwd
import subprocess
import sys

GOCRYPTFS = "@gocryptfs@"
FUSERMOUNT = "/run/wrappers/bin/fusermount3"  # NixOS's setuid wrapper
MEDIA = f"/run/media/{pwd.getpwuid(os.getuid()).pw_name}/Safe"


def is_safe(path):
    return os.path.isfile(os.path.join(path, "gocryptfs.conf"))


def mount_point(safe):
    """Where safe is unlocked: in a folder named by a hash of its path, so that
    safes with the same name don't collide, and named after it itself, which is
    what Nautilus calls it in its sidebar"""
    safe = os.path.realpath(safe)
    digest = hashlib.sha256(os.fsencode(safe)).hexdigest()[:16]
    return os.path.join(MEDIA, digest, os.path.basename(safe))


def create(safe, *options):
    """Make safe's folder, returning the command that makes it a safe"""
    os.mkdir(safe)
    return [GOCRYPTFS, "-init", "-q", *options, "--", safe]


def unlock(safe, *options):
    """Make where safe is unlocked, returning the command that unlocks it there"""
    mount = mount_point(safe)
    if os.path.ismount(mount):  # gocryptfs would mount over it
        raise FileExistsError(f"{os.path.basename(mount)} is already unlocked")
    os.makedirs(mount, exist_ok=True)
    return [GOCRYPTFS, "-q", *options, "--", safe, mount]


def remove(mount):
    """Remove where a safe was unlocked, if it was and it's locked"""
    if mount and os.path.dirname(os.path.dirname(mount)) == MEDIA:
        for path in (mount, os.path.dirname(mount)):
            try:
                os.rmdir(path)
            except OSError:  # still unlocked
                return


def describe(error):
    return f"{error.strerror}: {error.filename}" if error.strerror else str(error)


def terminal(args):
    if len(args) != 2 or args[0] not in ("create", "unlock", "lock"):
        return "usage: safe create|unlock|lock DIR"
    command, safe = args[0], os.path.abspath(args[1])
    mount = mount_point(safe)
    try:
        if command == "create":
            if subprocess.run(create(safe)).returncode:
                os.rmdir(safe)
                return 1
        elif not is_safe(safe):
            return f"safe: {args[1]} isn't a safe"
        elif command == "unlock":
            if subprocess.run(unlock(safe)).returncode:
                remove(mount)
                return 1
            print(mount)
        elif not os.path.ismount(mount):
            return f"safe: {args[1]} isn't unlocked"
        elif subprocess.run([FUSERMOUNT, "-u", mount]).returncode:
            return 1
        else:
            remove(mount)
    except OSError as error:
        return f"safe: {describe(error)}"
    return 0


if __name__ == "__main__":
    sys.exit(terminal(sys.argv[1:]))

# The rest is the Nautilus extension

from gi.repository import GLib, GObject, Gio, Nautilus  # noqa: E402

ZENITY = "@zenity@"
ICON = "metadata::custom-icon-name"  # where Nautilus keeps a file's own icon


def run(argv, done, input=None):
    """Run argv without blocking Nautilus, then call done(status, stdout, stderr)"""
    flags = Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
    if input is not None:
        flags |= Gio.SubprocessFlags.STDIN_PIPE
    process = Gio.Subprocess.new(argv, flags)

    def finish(_, result):
        _, stdout, stderr = process.communicate_utf8_finish(result)
        done(process.get_exit_status(), stdout, stderr.strip())

    process.communicate_utf8_async(input, None, finish)


def show_error(text):
    Gio.Subprocess.new(
        [ZENITY, "--error", "--no-markup", "--title=Safe", f"--text={text}"],
        Gio.SubprocessFlags.NONE,
    )


def ask_to_create(folder, problem=None):
    form = [ZENITY, "--forms", "--title=New Encrypted Folder", "--separator=\n"]
    form += [f"--text={problem or 'Choose a name and a password'}"]
    form += ["--add-entry=Name", "--add-password=Password", "--add-password=Repeat"]

    def answered(status, answers, _):
        if status != 0:  # cancelled
            return
        name, password, repeat = answers[:-1].split("\n")
        if name in ("", ".", "..") or "/" in name:
            return ask_to_create(folder, "Choose a name for the folder")
        if not password:
            return ask_to_create(folder, "Choose a password")
        if password != repeat:
            return ask_to_create(folder, "The passwords don't match")
        safe = os.path.join(folder, name)
        try:
            argv = create(safe, "-passfile=/dev/stdin")
        except FileExistsError:
            return ask_to_create(folder, f"There's already something called {name} here")
        except OSError as error:
            return show_error(describe(error))

        def done(status, _, error):
            if status != 0:
                os.rmdir(safe)
                show_error(f"Couldn't create {name}: {error}")

        run(argv, done, password + "\n")

    run(form, answered)


def ask_to_unlock(safe, prompt=None):
    name = os.path.basename(safe)
    # Several -extpass options are one command's arguments, not split on spaces
    ask = [ZENITY, "--password", f"--title={prompt or f'Password for {name}'}"]
    try:
        argv = unlock(safe, *(f"-extpass={arg}" for arg in ask))
    except OSError as error:
        return show_error(describe(error))

    def done(status, _, error):
        if status == 0:
            return
        remove(mount_point(safe))
        if status == 12:  # wrong (or empty) password
            ask_to_unlock(safe, f"Wrong password for {name}, try again")
        elif status != 9:  # 9: cancelled
            show_error(f"Couldn't unlock {name}: {error}")

    run(argv, done)


def local_path(file):
    return file.get_location().get_path() if file.get_uri_scheme() == "file" else None


class Safes(GObject.GObject, Nautilus.MenuProvider, Nautilus.InfoProvider):
    def __init__(self):
        super().__init__()
        # Remove where safes were unlocked once they're ejected, including any
        # ejected while Nautilus wasn't running
        self.monitor = Gio.VolumeMonitor.get()
        self.monitor.connect("mount-removed", lambda _, mount: remove(mount.get_root().get_path()))
        for mount in glob.glob(os.path.join(glob.escape(MEDIA), "*", "*")):
            remove(mount)

    def get_background_items(self, folder):
        path = local_path(folder)
        if not path or is_safe(path):  # not inside a safe's encrypted files
            return []
        item = Nautilus.MenuItem(name="Safe::Create", label="New Encrypted Folder…")
        item.connect("activate", lambda _: ask_to_create(path))
        return [item]

    def get_file_items(self, files):
        safe = local_path(files[0]) if len(files) == 1 else None
        if not safe or not is_safe(safe) or os.path.ismount(mount_point(safe)):
            return []
        item = Nautilus.MenuItem(name="Safe::Unlock", label="Unlock Encrypted Folder…")
        item.connect("activate", lambda _: ask_to_unlock(safe))
        return [item]

    def update_file_info(self, file):
        path = local_path(file)
        if not path or not is_safe(path):
            return
        location = file.get_location()
        flags = Gio.FileQueryInfoFlags.NONE
        try:
            if location.query_info(ICON, flags).get_attribute_string(ICON) != "folder-private":
                location.set_attribute_string(ICON, "folder-private", flags)
        except GLib.Error:  # somewhere Nautilus can't keep icons
            pass
