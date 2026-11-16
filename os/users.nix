{
  pkgs,
  inputs,
  lib,
  config,
  style,
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
      user = {
        description = "User";
        isNormalUser = true;
        uid = 1000;
        extraGroups = [
          "wheel"
          "networkmanager"
          "gamemode"
        ];
        hashedPasswordFile = "/etc/passwords/user";
      };
      guest = {
        description = "Guest";
        isNormalUser = true;
        uid = 1001;
        hashedPasswordFile = "/etc/passwords/guest";
      };
      root.hashedPasswordFile = "/etc/passwords/root";
    };
  };

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

  # Each user's /run/media/USER/Safe, where safe (home/packages/safe) unlocks
  # safes. udisks makes /run/media/USER only when it first mounts something,
  # owned by root, so it's made here as udisks would make it
  systemd.tmpfiles.rules = lib.concatMap (user: [
    "d /run/media/${user.name} 0750 root root -"
    "a+ /run/media/${user.name} - - - - u:${user.name}:r-x"
    "d /run/media/${user.name}/Safe 0700 ${user.name} ${user.group} -"
  ]) (lib.filter (user: user.isNormalUser) (lib.attrValues config.users.users));

  # Without ~/.gitconfig, git config --global writes to home-manager's read-only ~/.config/git/config
  system.userActivationScripts.gitconfig = "touch ~/.gitconfig";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs style; };
    backupFileExtension = "home-manager-backup";
    users = lib.genAttrs [ "root" "user" "guest" ] (_: ../home);
  };
}
