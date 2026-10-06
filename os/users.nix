{
  pkgs,
  inputs,
  specialArgs,
  lib,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.default
  ];

  # Password hashes are read from /data rather than /etc/passwords: the users
  # activation script runs at boot before impermanence bind-mounts /etc/passwords.
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
        hashedPasswordFile = "/data/etc/passwords/user";
      };
      "guest" = {
        description = "Guest";
        isNormalUser = true;
        extraGroups = [ ];
        hashedPasswordFile = "/data/etc/passwords/guest";
      };
      "root".hashedPasswordFile = "/data/etc/passwords/root";
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = specialArgs;
    backupFileExtension = "home-manager-backup";
    users = lib.genAttrs [ "root" "user" "guest" ] (user: {
      imports = [ ../home ];
    });
  };
}
