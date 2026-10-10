{
  pkgs,
  inputs,
  config,
  ...
}:
let
  luks = config.boot.initrd.luks.devices.crypted.device;
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
      # On first boot generate keys, then reboot so systemd-boot enrolls them.
      # Enrolling only happens while the firmware is in Setup Mode
      autoGenerateKeys.enable = true;
      autoEnrollKeys = {
        enable = true;
        autoReboot = true;
      };
    };
  };

  security.tpm2.enable = true;

  environment.systemPackages = [
    pkgs.sbctl
    # Seal the disk key to the TPM against the Secure Boot state (PCR 7), so it
    # unlocks without a password only while booting our signed images. Rerun
    # after the firmware's Secure Boot databases change, e.g. a dbx update
    (pkgs.writeShellApplication {
      name = "tpm-enroll";
      runtimeInputs = [ config.systemd.package ];
      text = ''
        # The variable's 4 attribute bytes are followed by 1 when Secure Boot is on
        state=$(od -An -tu1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c)
        if (( state != 1 )); then
          echo "Secure Boot is not enabled yet; enrolling now would seal the key to an insecure state" >&2
          exit 1
        fi
        sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 ${luks}
      '';
    })
  ];
}
