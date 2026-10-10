{ pkgs, ... }:
{
  imports = [
    ./gnome.nix
    ./hardware.nix
    ./users.nix
  ];
  networking.hostName = "aura";
  system.stateVersion = "26.11";
  environment.systemPackages = with pkgs; [
    hunspellDicts.en_GB-ize
  ];
  boot = {
    tmp.useTmpfs = true;
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "quiet"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    kernel.sysctl = {
      "vm.swappiness" = 10;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 0;
    };
    plymouth.enable = true;
    initrd = {
      systemd.enable = true;
      verbose = false;
    };
    consoleLogLevel = 0;
  };
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.useXkbConfig = true;
  services = {
    xserver.xkb.layout = "gb";
    logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
    avahi.nssmdns4 = true;
    ipp-usb.enable = true;
    fwupd.enable = true;
    printing.enable = true;
    # Let wheel read the CPU energy counters, for Mission Center's power draw.
    # They're root-only because of the Platypus side channel, but wheel can
    # sudo without a password anyway, so this only keeps them from guest
    udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl*", RUN+="${pkgs.coreutils}/bin/chgrp wheel /sys%p/energy_uj", RUN+="${pkgs.coreutils}/bin/chmod g+r /sys%p/energy_uj"
    '';
  };
  systemd.sleep.settings.Sleep.HibernateDelaySec = "24h";
  programs = {
    zsh.enable = true;
    gamemode.enable = true;
    nh = {
      enable = true;
      flake = "/etc/nixos";
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
  };
  security = {
    sudo = {
      wheelNeedsPassword = false;
      extraConfig = "Defaults:root,%wheel env_keep+=SHLVL";
    };
    # Mission Center runs nethogs from PATH to show each process's network usage,
    # which needs these capabilities
    wrappers.nethogs = {
      source = "${pkgs.nethogs}/bin/nethogs";
      capabilities = "cap_net_admin,cap_net_raw,cap_dac_read_search,cap_sys_ptrace+ep";
      owner = "root";
      group = "root";
    };
  };
  documentation.nixos.enable = false;
  nix = {
    channel.enable = false;
    settings = {
      download-buffer-size = 256 * 1024 * 1024;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
  hardware.enableAllFirmware = true;
}
