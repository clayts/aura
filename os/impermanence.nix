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
      "size=2G"
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
      {
        directory = "/etc/passwords/";
        mode = "0700";
      }
      {
        directory = "/etc/nixos/";
        user = "user";
        group = "users";
      }
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
        ".local/"
        ".config/mozilla/"
        ".config/goa-1.0/"
        ".wine/"
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
        {
          file = ".gitconfig";
          method = "symlink";
        }
      ];
    };
  };
  # The symlinked ~/.gitconfig needs its target to exist
  systemd.tmpfiles.rules = [ "f /data/home/user/.gitconfig :0644 user users -" ];
}
