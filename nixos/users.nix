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
        hashedPasswordFile = "/data/etc/nixos/passwords/user";
      };
      "guest" = {
        description = "Guest";
        isNormalUser = true;
        extraGroups = [ ];
        hashedPasswordFile = "/data/etc/nixos/passwords/guest";
      };
      "root".hashedPasswordFile = "/data/etc/nixos/passwords/root";
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = specialArgs;
    backupFileExtension = "home-manager-backup";
    users = lib.genAttrs [ "root" "user" "guest" ] (user: {
      imports = [ ../home-manager ];
    });
  };
}
