{ pkgs, ... }:
{
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    gnome = {
      core-apps.enable = false;
      gnome-online-accounts.enable = true;
      gnome-remote-desktop.enable = true;
    };
  };
  environment = {
    sessionVariables.NAUTILUS_4_EXTENSION_DIR = "/run/current-system/sw/lib/nautilus/extensions-4";
    pathsToLink = [ "/share/nautilus-python/extensions" ];
    gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-screenshot
    ];
  };
  security.pam.services = {
    gdm-fingerprint.fprintAuth = true;
    login.fprintAuth = false;
  };
  programs.dconf = {
    enable = true;
    profiles.gdm.databases = [
      { settings."org/gnome/login-screen".enable-fingerprint-authentication = false; }
    ];
  };
}
