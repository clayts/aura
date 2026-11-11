# Aura

NixOS configuration for `aura`

## Install
1. In the firmware settings (F1 at the Lenovo logo):
   - Set a supervisor password, so nobody else can change the settings below.
   - Turn Security Chip (the TPM) on.
   - Turn Secure Boot on, then reset it to Setup Mode.
     Setup Mode clears the Secure Boot keys, so nothing is enforced and the unsigned installer boots.
     The installer enrolls this install's keys at the end, and Secure Boot enforces them from the next boot.
2. Boot a NixOS installer from USB (F12 for the boot menu) and connect to the network, e.g. with `nmtui`.
3. If the drive has never been encrypted, or was factory reset, the installer has to take ownership of it, which the firmware blocks at every boot ("Block SID").
   Ask it to skip that once:
   ```sh
   echo 97 | sudo tee /sys/class/tpm/tpm0/ppi/request
   ```
   Reboot, confirm the firmware's prompt, and boot the installer again, then go straight to step 4: the next boot blocks it again.
   Reinstalling over an install of this configuration doesn't need this.
4. Run `nix run --experimental-features "nix-command flakes" github:clayts/aura#install`, which runs `install.sh`.
   It asks every question first, then erases the disk declared in `os/hardware.nix` and installs unattended.
5. Reboot, remove the USB stick and enter the disk password.
   That boot seals the disk key to the TPM, so later boots unlock without it.
   `bootctl status` then shows `Secure Boot: enabled (user)`, and `sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-luks` lists a `tpm2` slot.

`/etc/nixos` is a clone of this repository, on the branch that was installed.

## Encryption
The disk is LUKS2 in OPAL hardware-only mode (`cryptsetup --hw-opal-only`): the drive does the encryption, and LUKS stores and unlocks the drive's key.
`/` is XFS directly inside it, so the swap files swapspace creates there are encrypted too.

The installer creates Secure Boot keys, enrolls them alongside Microsoft's, and Lanzaboote signs everything on the ESP with them.
If the firmware wasn't in Setup Mode, systemd-boot enrolls them whenever it is.
With Secure Boot enforcing, `tpm-enroll.service` seals the disk key to the TPM, so it only unlocks while Secure Boot is in the same state and nothing planted on the ESP or another disk has run.
When a firmware update changes the Secure Boot state, the disk asks for its password once and the service seals it again.

The disk password is also the drive's OPAL admin password, which stays the same until the drive is factory reset, even if the disk password changes.
Reinstalling asks for it to erase the previous install, and keeps it as the new disk password.
If it's lost, the installer can factory reset the drive with the PSID printed on its label.

The installer is unsigned, so booting it again later needs Secure Boot turned off for the time being, or reset to Setup Mode to reinstall.
