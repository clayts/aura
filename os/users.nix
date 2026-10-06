{
  pkgs,
  inputs,
  style,
  packages,
  lib,
  config,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.default
  ];

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;
    users = {
      "user" = {
        description = "User";
        isNormalUser = true;
        uid = 1000;
        extraGroups = [
          "wheel"
          "libvirtd"
          "networkmanager"
        ];
        hashedPasswordFile = "/etc/passwords/user";
      };
      "guest" = {
        description = "Guest";
        isNormalUser = true;
        uid = 1001;
        hashedPasswordFile = "/etc/passwords/guest";
      };
      "root".hashedPasswordFile = "/etc/passwords/root";
    };
  };

  # Empty at every boot; home-manager fills it before logins are allowed
  fileSystems."/home/guest" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "size=1G"
      "mode=700"
      "uid=${toString config.users.users.guest.uid}"
      "gid=${toString config.users.groups.users.gid}"
    ];
  };

  # Without ~/.gitconfig, git config --global writes to home-manager's
  # read-only ~/.config/git/config
  systemd.tmpfiles.rules = [ "f /home/user/.gitconfig :0644 user users -" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs style packages; };
    backupFileExtension = "home-manager-backup";
    users = lib.genAttrs [ "root" "user" "guest" ] (_: ../home);
  };
}
