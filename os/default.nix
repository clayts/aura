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
    initrd.verbose = false;
    consoleLogLevel = 0;
  };
  virtualisation.libvirtd.enable = true;
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
  };
  systemd.sleep.settings.Sleep.HibernateDelaySec = "24h";
  programs = {
    zsh.enable = true;
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
  security.sudo = {
    wheelNeedsPassword = false;
    extraConfig = "Defaults:root,%wheel env_keep+=SHLVL";
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
