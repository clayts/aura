# Aura

NixOS configuration for `aura`, kept at `/etc/nixos` (owned by `user`).

- `os/` NixOS modules, with system packages in `os/packages/`
- `home/` Home Manager modules (shared by `root`, `user` and `guest`), with user packages in `home/packages/`
- `style/` fonts, colours, icons and cursors

## Install
From a NixOS installer, run `nix run --experimental-features "nix-command flakes" github:clayts/aura#install`.
This erases the disk declared in `os/hardware.nix`.

## To Do
- rename data -> static?
