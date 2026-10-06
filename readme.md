# Aura

NixOS configuration for `aura`, kept at `/etc/nixos` (owned by `user`).

- `os/` NixOS modules, with system packages in `os/packages/`
- `home/` Home Manager modules (shared by `root`, `user` and `guest`), with user packages in `home/packages/`
- `style/` fonts, colours, icons and cursors

## Install
From a NixOS installer, run `nix run --experimental-features "nix-command flakes" github:clayts/aura#install`.
This erases the disk declared in `os/hardware.nix`.

## Use
- `system sync` builds `/etc/nixos` and switches to it.
- `system update` pulls `/etc/nixos`, updates its inputs, switches, then commits and pushes `flake.lock`.
- `--boot` makes either one take effect at the next boot instead. `system clean` collects garbage.
- Passwords are hashes in `/etc/passwords/<name>`. To change one, run `mkpasswd | sudo tee /etc/passwords/<name>`, then `system sync`.
- `nix fmt` formats the Nix files.
