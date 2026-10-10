{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:
let
  luks = config.boot.initrd.luks.devices.crypted.device;
  # Added to the disk by the installer
  key = "/var/lib/tpm-enroll/key";
  zero = lib.strings.replicate 64 "0";
  # PCR 7 is the Secure Boot state. 12 and 13 stay zero unless the boot loads
  # credentials or system extensions from the ESP, and 15 stays zero until a
  # disk is unlocked, so neither those nor a planted disk unlocked first can get
  # the key unsealed
  pcrs = "7:sha256+12:sha256=${zero}+13:sha256=${zero}+15:sha256=${zero}";
in
{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  boot = {
    # Kernel command line edits would bypass what the TPM key is sealed to
    loader.systemd-boot.editor = false;
    # Lanzaboote installs systemd-boot and signs everything it puts on the ESP
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      # The ESP is 2G and holds a kernel and initrd for each boot entry
      configurationLimit = 10;
      # The installer creates and enrolls the keys. Otherwise these generate
      # them on first boot and have systemd-boot enroll them whenever the
      # firmware is in Setup Mode
      autoGenerateKeys.enable = true;
      autoEnrollKeys.enable = true;
    };
    # Only the unlocked disk may provide LVM volumes in the initrd, so a planted
    # volume group can't stand in for root or the resume image
    initrd.systemd.contents."/etc/lvm/lvm.conf".text = ''
      devices/global_filter = [ "a|^/dev/mapper/crypted$|", "r|.*|" ]
    '';
  };

  security.tpm2.enable = true;
  environment.systemPackages = [ pkgs.sbctl ];

  # Seal the disk key to the TPM, so it unlocks without a password only while
  # booting this install's signed images. Reseal whenever what the seal depends
  # on changes, e.g. after a firmware update changes the Secure Boot databases
  systemd.services.tpm-enroll = {
    description = "Seal the disk key to the TPM";
    wantedBy = [ "multi-user.target" ];
    after = [
      "tpm2.target"
      "systemd-tpm2-setup.service"
    ];
    unitConfig = {
      ConditionSecurity = [
        "uefi-secureboot"
        "tpm2"
      ];
      ConditionPathExists = key;
    };
    environment = {
      KEY = key;
      LUKS = luks;
    };
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "tpm-enroll";
      StateDirectoryMode = "0700";
    };
    script = ''
      # What the seal depends on: the Secure Boot state and the TPM's storage root key
      fingerprint() { { cat /sys/class/tpm/tpm0/pcr-sha256/7; systemd-analyze srk; } | sha256sum; }
      sealed=$STATE_DIRECTORY/sealed
      slots=$(systemd-cryptenroll "$LUKS")
      if [[ $slots == *tpm2* && $(fingerprint) == "$(cat "$sealed" 2>/dev/null)" ]]; then
        exit 0
      fi
      systemd-cryptenroll --unlock-key-file="$KEY" --wipe-slot=tpm2 \
        --tpm2-device=auto --tpm2-pcrs=${pcrs} "$LUKS"
      fingerprint > "$sealed"
    '';
  };
}
