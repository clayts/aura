import os
import shutil
import stat

import gi

gi.require_version("Nautilus", "4.0")
from gi.repository import (
    GObject,  # pyright: ignore[reportMissingModuleSource]
    Nautilus,  # pyright: ignore[reportAttributeAccessIssue]
)

TEMPLATES = "@templates@"


def unique_path(path):
    candidate, n = path, 1
    while os.path.lexists(candidate):
        n += 1
        candidate = f"{path} {n}"
    return candidate


def make_writable(root):
    # Templates come from the read-only Nix store
    for dirpath, dirnames, filenames in os.walk(root):
        for name in [dirpath] + [os.path.join(dirpath, f) for f in filenames]:
            mode = os.lstat(name).st_mode
            if not stat.S_ISLNK(mode):
                os.chmod(name, mode | stat.S_IWUSR)


def create(_item, template, folder):
    target = unique_path(os.path.join(folder, template))
    shutil.copytree(os.path.join(TEMPLATES, template), target, symlinks=True)
    make_writable(target)


class FolderTemplates(GObject.GObject, Nautilus.MenuProvider):
    def get_background_items(self, current_folder):
        folder = current_folder.get_location().get_path()
        if folder is None:
            return []
        submenu = Nautilus.Menu()
        for template in sorted(os.listdir(TEMPLATES)):
            item = Nautilus.MenuItem(
                name=f"FolderTemplates::{template}", label=template
            )
            item.connect("activate", create, template, folder)
            submenu.append_item(item)
        menu = Nautilus.MenuItem(
            name="FolderTemplates", label="New Folder From Template"
        )
        menu.set_submenu(submenu)
        return [menu]
