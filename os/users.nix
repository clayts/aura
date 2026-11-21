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

  # Each user's /run/media/USER/user: a folder of their own for their tools'
  # mounts, each tool in a subfolder (like safe.py's safe), which Nautilus
  # lists in its sidebar. /run/media/USER itself stays as udisks makes it,
  # owned by root, since udisks makes folders there and mounts on them as root,
  # and the user mustn't be able to swap those from under it. udisks never
  # touches user. (A name starting with a dot would hide its mounts)
  systemd.tmpfiles.rules = lib.concatMap (user: [
    "d /run/media/${user.name} 0750 root root -"
    "a+ /run/media/${user.name} - - - - u:${user.name}:r-x"
    "d /run/media/${user.name}/user 0700 ${user.name} ${user.group} -"
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
