{ config, pkgs, ... }:
{
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
  environment = {
    systemPackages = [ pkgs.nautilus-python ]; # Nautilus loads extensions only from the system profile
    gnome.excludePackages = with pkgs; [
      decibels
      epiphany
      gnome-connections
      gnome-console
      gnome-contacts
      gnome-font-viewer
      gnome-maps
      gnome-music
      gnome-system-monitor
      gnome-tecla
      gnome-text-editor
      gnome-tour
      gnome-weather
      seahorse
      showtime
      simple-scan
      sushi
    ];
  };
  programs.dconf.profiles.gdm.databases = [
    { settings."org/gnome/login-screen".enable-fingerprint-authentication = false; }
  ];
  # Turn on "Preserve Battery Health" (UPower's charge threshold) at every boot
  systemd.services.preserve-battery-health = {
    description = "Enable UPower battery charge threshold";
    wantedBy = [ "multi-user.target" ];
    wants = [ "upower.service" ];
    after = [ "upower.service" ];
    path = [
      config.services.upower.package
      config.systemd.package
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      for battery in $(upower --enumerate | grep battery_); do
        busctl call org.freedesktop.UPower "$battery" org.freedesktop.UPower.Device \
          EnableChargeThreshold b true
      done
    '';
  };
}
