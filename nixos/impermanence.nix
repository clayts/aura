{ inputs, ... }:
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=32M"
      "mode=755"
    ];
  };
  environment.persistence."/data" = {
    allowTrash = true;
    hideMounts = true;
    directories = [
      "/nix/"
      "/var/"
      "/etc/NetworkManager/system-connections/"
      "/etc/ssh/"
      "/etc/nixos/"
    ];
    files = [
      "/etc/machine-id"
      "/etc/adjtime"
    ];
    users."user" = {
      directories = [
        "Desk/"
        "Media/"
        "Code/"
        "Documents/"

        ".Public/"
        ".local"
        ".config/mozilla/"
        ".config/goa-1.0/"
        ".wine"
        {
          directory = ".cache/";
          mode = "0700";
        }
        {
          directory = ".config/gh/";
          mode = "0751";
        }
      ];
      files = [
        ".local/share/recently-used.xbel"
        {
          file = ".gitconfig";
          method = "symlink";
        }
      ];
    };
  };
  system.activationScripts.fix-config-files = {
    text = ''
      touch /data/home/user/.gitconfig
    '';
  };
}
