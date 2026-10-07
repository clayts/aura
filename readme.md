# Aura

NixOS configuration for `aura`

## Install
From a NixOS installer, run `nix run --experimental-features "nix-command flakes" github:clayts/aura#install`, which runs `install.sh`.
This erases the disk declared in `os/hardware.nix`.

## Use
- `system test` builds `/etc/nixos` as it is and switches to it.
- `system sync` pulls `/etc/nixos` and switches to it, without updating its inputs.
- `system update` pulls `/etc/nixos`, updates its inputs, switches, then commits and pushes `flake.lock`.
- `--boot` makes any of these take effect at the next boot instead. `system clean` collects garbage.
- Passwords are hashes in `/etc/passwords/<name>`. To change one, run `mkpasswd | sudo tee /etc/passwords/<name>`, then `system test`.
- `nix fmt` formats the Nix files.
