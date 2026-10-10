# Aura

NixOS configuration for `aura`

## Install
From a NixOS installer, run `nix run --experimental-features "nix-command flakes" github:clayts/aura#install`, which runs `install.sh`.
This erases the disk declared in `os/hardware.nix`.

## Encryption
The root disk uses LUKS2 in OPAL hardware-only mode (`cryptsetup --hw-opal-only`): the drive does the encryption, and LUKS stores and unlocks the drive's key.
Swap and `/` are LVM volumes inside it, so hibernation images are encrypted too.
The installer asks for two passwords:
- a **recovery password**, which unlocks the disk at boot whenever the TPM won't
- an **OPAL admin password**, which owns the drive's locking range and is needed to erase or reformat it

### First boot
1. In the firmware settings, set a supervisor password and put Secure Boot into **Setup Mode** (clear or reset to setup mode), before booting the new system.
2. Boot and enter the recovery password. Lanzaboote generates Secure Boot keys, then reboots so systemd-boot enrolls them, which turns Secure Boot on.
3. Enter the recovery password again, log in, and run `tpm-enroll`. From then on the TPM unlocks the disk at boot.

If the TPM stops unlocking, which happens after a firmware update changes the Secure Boot databases, enter the recovery password and run `tpm-enroll` again.

### Reinstalling
A drive formatted with OPAL stays locked until its locking range is erased, so disko can't wipe it.
Erase it first with `sudo cryptsetup erase /dev/disk/by-partlabel/disk-main-luks`, which asks for the OPAL admin password.
If the OPAL admin password is lost, `sudo cryptsetup erase --hw-opal-factory-reset /dev/nvme0n1` resets the whole drive using the PSID printed on its label.
