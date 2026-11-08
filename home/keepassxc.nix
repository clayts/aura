{ pkgs, lib, ... }:
let
  qtPlugins = lib.makeSearchPath pkgs.qt6.qtbase.qtPluginPrefix (
    with pkgs;
    [
      qgnomeplatform-qt6
      adwaita-qt6
      qadwaitadecorations-qt6
    ]
  );
in
{
  programs.keepassxc = {
    enable = true;
    # KeePassXC made to look like a GNOME app, on its own rather than through
    # the session's Qt settings, so other Qt apps keep their own look.
    # QGnomePlatform takes GNOME's fonts, icons, light or dark style
    # (Adwaita-qt's Adwaita or Adwaita Dark) and file dialogs, and
    # QAdwaitaDecorations draws libadwaita's title bar under Wayland
    package = pkgs.symlinkJoin {
      name = "keepassxc";
      paths = [ pkgs.keepassxc ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/keepassxc \
          --prefix QT_PLUGIN_PATH : ${qtPlugins} \
          --set QT_QPA_PLATFORMTHEME qgnomeplatform \
          --set QT_WAYLAND_DECORATION adwaita
      '';
      meta.mainProgram = "keepassxc";
    };
    # KeePassXC's light and dark themes replace the Qt style with its own;
    # only its classic theme keeps it
    settings.GUI.ApplicationTheme = "classic";
  };
}
