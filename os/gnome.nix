{ pkgs, style, ... }:
{
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
  fonts.packages = map (font: font.package) (builtins.attrValues style.fonts);
  environment = {
    systemPackages = [
      style.icons.package
      style.cursors.package
    ];
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
      xdg-user-dirs-gtk
    ];
  };
  programs.dconf.profiles.gdm.databases = [
    {
      settings = {
        "org/gnome/login-screen".enable-fingerprint-authentication = false;
        "org/gnome/desktop/interface" = style.gnome.interface;
      };
    }
  ];
}
