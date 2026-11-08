{ pkgs, ... }:
{
  programs.keepassxc = {
    enable = true;
    # KeePassXC made to look like a GNOME app, on its own rather than through
    # the session's Qt settings, so other Qt apps keep their own look.
    # Qt's GTK 3 platform theme takes GNOME's fonts, icons, dark mode, file
    # dialogs and, from adw-gtk3, colours, for its Fusion style; and
    # QAdwaitaDecorations draws libadwaita's title bar under Wayland
    package = pkgs.symlinkJoin {
      name = "keepassxc";
      paths = [ pkgs.keepassxc ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/keepassxc \
          --prefix QT_PLUGIN_PATH : ${pkgs.qadwaitadecorations-qt6}/${pkgs.qt6.qtbase.qtPluginPrefix} \
          --set QT_QPA_PLATFORMTHEME gtk3 \
          --set QT_STYLE_OVERRIDE Fusion \
          --set QT_WAYLAND_DECORATION adwaita
      '';
      meta.mainProgram = "keepassxc";
    };
    # KeePassXC's light and dark themes replace the Qt style with its own;
    # only its classic theme keeps it
    settings.GUI = {
      ApplicationTheme = "classic";
      ShowTrayIcon = true;
      MinimizeOnStartup = true;
      MinimizeToTray = true;
      HideToolbar = true;
      HideMenubar = true;
    };
    autostart = true;
  };
  xdg.autostart.enable = true;
}
