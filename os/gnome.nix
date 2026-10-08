{ pkgs, ... }:
{
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
  environment = {
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
}
