{
  pkgs,
  lib,
  config,
  ...
}:
let
  ini = "${config.xdg.configHome}/keepassxc/keepassxc.ini";
  # KeePassXC with the Adwaita Qt style, on its own rather than as the
  # session's Qt style, so other Qt apps keep their own
  keepassxc = pkgs.symlinkJoin {
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
in
{
  home.packages = [ keepassxc ];
  # KeePassXC's light and dark themes replace the Qt style with its own; only
  # its classic theme keeps it. The setting is written into keepassxc.ini at
  # each activation, rather than the file being linked from the store, so
  # KeePassXC can still save its other settings there
  home.activation.keepassxc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg (dirOf ini)}
    run ${lib.getExe pkgs.crudini} --ini-options=nospace \
      --set ${lib.escapeShellArg ini} GUI ApplicationTheme classic
  '';
}
