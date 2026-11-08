{ pkgs, ... }:
{
  programs.keepassxc = {
    enable = true;
    # KeePassXC with the Adwaita Qt style, on its own rather than as the
    # session's Qt style, so other Qt apps keep their own
    package = pkgs.symlinkJoin {
      name = "keepassxc";
      paths = [ pkgs.keepassxc ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/keepassxc \
          --prefix QT_PLUGIN_PATH : ${pkgs.adwaita-qt6}/${pkgs.qt6.qtbase.qtPluginPrefix} \
          --set QT_STYLE_OVERRIDE adwaita
      '';
      meta.mainProgram = "keepassxc";
    };
    # KeePassXC's light and dark themes replace the Qt style with its own;
    # only its classic theme keeps it
    settings.GUI.ApplicationTheme = "classic";
  };
}
