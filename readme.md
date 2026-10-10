# Aura

NixOS configuration for `aura`

## Install
1. In the firmware settings, set a supervisor password, turn Secure Boot on and reset it to Setup Mode. The installer offers to reboot into the firmware settings if it isn't in Setup Mode.
2. From a NixOS installer, run `nix run --experimental-features "nix-command flakes" github:clayts/aura#install`, which runs `install.sh`.
   It asks its questions up front, then erases the disk declared in `os/hardware.nix` and installs unattended.
3. Reboot and enter the disk password. From the next boot on, the TPM unlocks the disk.

`/etc/nixos` is a clone of this repository, on the branch that was installed.

## Encryption
The disk is LUKS2 in OPAL hardware-only mode (`cryptsetup --hw-opal-only`): the drive does the encryption, and LUKS stores and unlocks the drive's key.
Swap and `/` are LVM volumes inside it, so hibernation images are encrypted too.

The installer creates Secure Boot keys, enrolls them alongside Microsoft's, and Lanzaboote signs everything on the ESP with them.
If the firmware wasn't in Setup Mode, systemd-boot enrolls them whenever it is.
With Secure Boot enforcing, `tpm-enroll.service` seals the disk key to the TPM, so it only unlocks while Secure Boot is in the same state and nothing planted on the ESP or another disk has run.
When a firmware update changes the Secure Boot state, the disk asks for its password once and the service seals it again.

The disk password is also the drive's OPAL admin password, which stays the same until the drive is factory reset, even if the disk password changes.
Reinstalling asks for it to erase the previous install, and keeps it as the new disk password.
If it's lost, the installer can factory reset the drive with the PSID printed on its label.

The installer is unsigned, so booting it needs Secure Boot turned off or reset to Setup Mode.
