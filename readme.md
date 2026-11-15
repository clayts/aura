# Aura

NixOS configuration for `aura`

## Install
Run the installer from a NixOS installer on USB with
`nix run --experimental-features "nix-command flakes" github:clayts/aura#install`, which runs `install.sh`.
To install another branch, name it after `aura`, e.g. `github:clayts/aura/luks#install`.
It asks every question before it erases anything, then erases the disk declared in `os/hardware.nix` and installs unattended.
F1 at the Lenovo logo opens the firmware settings, and F12 the boot menu.

### First install
For a drive that has never been encrypted, such as an install of a version without encryption, or one that was factory reset.

1. Back up anything you want to keep: the whole disk is erased.
2. In the firmware settings, set a supervisor password, turn Security Chip on, turn Secure Boot on and then reset it to Setup Mode.
   Setup Mode clears the Secure Boot keys, so the unsigned installer boots, and the installer enrolls this install's keys at the end.
3. Boot the installer from USB, connect to the network, e.g. with `nmtui`, and run the installer.
4. The drive has to be taken over once, which the firmware blocks at every boot (Block SID), so the installer asks the firmware to allow it on the next boot and offers to reboot.
   The next boot confirms that in a firmware prompt and should start the installer again (otherwise choose it with F12): run the installer again.
   Going through the firmware settings in between undoes that, and the installer asks again.
5. Choose the disk password, then the passwords for root, user and guest.
   The disk password is also the drive's OPAL admin password, which every later reinstall asks for.
6. When it's done, reboot, remove the USB stick and enter the disk password.
   That boot seals the disk key to the TPM, so later boots unlock without it.
   `bootctl status` shows `Secure Boot: enabled (user)`, and `sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-luks` lists a `tpm2` slot.

### Reinstall
For a drive with an install of this configuration on it.

1. Back up anything you want to keep.
2. In the firmware settings, reset Secure Boot to Setup Mode, leaving Secure Boot on.
3. Boot the installer from USB, connect to the network and run the installer.
4. It finds the previous install and asks for its disk password, which it erases the drive with and keeps for the new install.
   If the password is lost, leave it empty to factory reset the drive with the PSID printed on its label.
   The installer then asks the firmware to allow taking over the drive again and offers to power off, since the drive also needs a power cycle.
   Power on, confirm the firmware's prompt and run the installer again once it has started, which carries on as a first install from step 5.
5. Choose the passwords for root, user and guest, and when it's done, reboot and enter the disk password once.

`/etc/nixos` is a clone of this repository, on the branch that was installed.

## Encryption
The disk is LUKS2 in OPAL hardware-only mode (`cryptsetup --hw-opal-only`): the drive does the encryption, and LUKS stores and unlocks the drive's key.
`/` is XFS directly inside it, so the swap files swapspace creates there are encrypted too.

The installer creates Secure Boot keys, enrolls them alongside Microsoft's, and Lanzaboote signs everything on the ESP with them.
If the firmware wasn't in Setup Mode, systemd-boot enrolls them whenever it is.
With Secure Boot enforcing, `tpm-enroll.service` seals the disk key to the TPM, so it only unlocks while Secure Boot is in the same state and nothing planted on the ESP or another disk has run.
When a firmware update changes the Secure Boot state, the disk asks for its password once and the service seals it again.

The disk password is also the drive's OPAL admin password, which stays the same until the drive is factory reset, even if the disk password changes.

The installer is unsigned, so booting it again later needs Secure Boot turned off for the time being, or reset to Setup Mode to reinstall.
