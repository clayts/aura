{ pkgs, ... }:
{
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    gnome.core-apps.enable = false;
  };
  environment = {
    # Nautilus is installed system-wide so it finds its extensions here
    systemPackages = with pkgs; [
      nautilus
      nautilus-python
    ];
    sessionVariables.NAUTILUS_4_EXTENSION_DIR = "/run/current-system/sw/lib/nautilus/extensions-4";
    gnome.excludePackages = [ pkgs.gnome-tour ];
  };
  xdg.mime.defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
  programs.dconf.profiles.gdm.databases = [
    { settings."org/gnome/login-screen".enable-fingerprint-authentication = false; }
  ];
}
