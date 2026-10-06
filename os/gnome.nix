{ pkgs, ... }:
{
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    gnome.core-apps.enable = false;
  };
  environment = {
    sessionVariables.NAUTILUS_4_EXTENSION_DIR = "/run/current-system/sw/lib/nautilus/extensions-4";
    pathsToLink = [ "/share/nautilus-python/extensions" ];
    gnome.excludePackages = [ pkgs.gnome-tour ];
  };
  programs.dconf.profiles.gdm.databases = [
    { settings."org/gnome/login-screen".enable-fingerprint-authentication = false; }
  ];
}
