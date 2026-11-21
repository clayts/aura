# Aura

NixOS configuration for `aura`

## Install
From a NixOS installer, run `nix run --experimental-features "nix-command flakes" github:clayts/aura#install`, which runs `install.sh`.
This erases the disk declared in `os/hardware.nix`.

## Google Drive
Drive's `Cloud` folder can be mounted at `~/Cloud` with rclone.

To set up, once per computer, make your own Google OAuth client (rclone's shared one is being retired) by following https://rclone.org/drive/#making-your-own-client-id, then run this, which opens a browser to sign in to Google:
```bash
rclone config create gdrive drive scope=drive client_id=CLIENT_ID client_secret=CLIENT_SECRET
```
This saves the sign-in in `~/.config/rclone/rclone.conf`. If it expires, sign in again with `rclone config reconnect gdrive:`.

To mount, which lasts until you unmount or log out:
```bash
mkdir -p ~/Cloud
rclone mount gdrive:Cloud ~/Cloud --vfs-cache-mode full --daemon
```
`--vfs-cache-mode full` keeps a cache in `~/.cache/rclone`, so files open like local ones and edits upload in the background, a few seconds after they're closed.

To unmount, once nothing is still uploading:
```bash
fusermount3 -u ~/Cloud
```
