# Aura

NixOS configuration for `aura`

## Install
From a NixOS installer, run:
```bash
nix-shell -p gh --run 'gh auth login --web --git-protocol https --insecure-storage && nix --extra-experimental-features "nix-command flakes" --option access-tokens "github.com=$(gh auth token)" run github:clayts/aura#install'
```
The repo is private, so this first logs in to GitHub: open https://github.com/login/device on any device and enter the code shown.
It then runs `install.sh`, which clones the repo to `/etc/nixos` and carries the login over to the installed system, so `git pull` and `git push` work there from the first boot.
This erases the disk declared in `os/hardware.nix`.
