{ lib, ... }:
{
  # COSMIC alongside GNOME, to try it out: GDM lists it as a session to log in to
  services.desktopManager.cosmic.enable = true;
  # COSMIC would set QT_QPA_PLATFORMTHEME=qt5ct for every session, GNOME's too
  qt.enable = lib.mkForce false;
}
