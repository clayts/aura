{ pkgs, lib, ... }:
let
  style = import ../home/style { inherit pkgs; };
in
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
  # GDM runs as its own user, so give it the same look as home-manager gives users
  fonts.packages = map (font: font.package) (lib.attrValues style.fonts);
  environment.systemPackages = [
    style.cursors.package
    style.icons.package
  ];
  programs.dconf.profiles.gdm.databases = [
    {
      settings = {
        "org/gnome/login-screen".enable-fingerprint-authentication = false;
        "org/gnome/desktop/interface" = with style; {
          font-name = "${fonts.sans.name} ${toString fonts.sans.size}";
          cursor-theme = cursors.name;
          icon-theme = icons.name;
        };
      };
    }
  ];
}
