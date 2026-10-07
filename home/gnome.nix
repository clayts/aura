{
  pkgs,
  lib,
  config,
  ...
}:
let
  style = import ./style { inherit pkgs; };
  packages = import ./packages { inherit pkgs; };
  wallpaper = "${config.xdg.dataHome}/earthpaper/image.jpeg";
  blankWallpaper = pkgs.runCommand "blank-wallpaper.jpeg" { } ''
    ${lib.getExe' pkgs.imagemagick "magick"} -size 1x1 'xc:${style.colors.x0}' $out
  '';
in
{
  gtk = {
    enable = true;
    iconTheme = style.icons;
    gtk3 = {
      theme = {
        name = "adw-gtk3";
        package = pkgs.adw-gtk3;
      };
      bookmarks = map (dir: "file://${dir}") (
        with config.xdg.userDirs;
        [
          desktop
          music
          projects
          documents
        ]
      );
    };
    cursorTheme = style.cursors;
  };
  programs.gnome-shell = {
    enable = true;
    extensions = map (package: { inherit package; }) (
      with pkgs.gnomeExtensions;
      [
        grand-theft-focus
        appindicator
        alphabetical-app-grid
        just-perfection
        auto-power-profile
      ]
    );
  };
  home.packages = [ packages.earthpaper ];
  xdg.configFile."autostart/earthpaper.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Earthpaper
    Exec=${lib.getExe packages.earthpaper} ${wallpaper}
    X-GNOME-Autostart-enabled=true
    NoDisplay=true
  '';
  # GNOME Shell only notices the wallpaper changing if it existed at login, so
  # leave a blank one for earthpaper to overwrite
  home.activation.earthpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e ${lib.escapeShellArg wallpaper} ]]; then
      run install -D -m 644 ${blankWallpaper} ${lib.escapeShellArg wallpaper}
    fi
  '';
  dconf.settings = {
    "org/gnome/shell".favorite-apps = [
      "firefox.desktop"
      "org.gnome.Nautilus.desktop"
    ];
    "org/gnome/shell/extensions/just-perfection" = {
      panel = false;
      panel-in-overview = true;
      activities-button = false;
      quick-settings-dark-mode = false;
      quick-settings-night-light = false;
      quick-settings-airplane-mode = false;
      window-preview-caption = false;
      background-menu = false;
      support-notifier-type = 0;
    };
    "org/gnome/shell/window-switcher".current-workspace-only = false;
    "org/gnome/mutter" = {
      dynamic-workspaces = true;
      edge-tiling = true;
      workspaces-only-on-primary = true;
    };
    "org/gnome/desktop/interface" = with style.fonts; {
      font-name = "${sans.name} ${toString sans.size}";
      document-font-name = "${serif.name} ${toString serif.size}";
      monospace-font-name = "${mono.name} ${toString mono.size}";
      gtk-enable-primary-paste = false; # Disable middle-click paste as it can accidentally paste stuff when scrolling
      enable-hot-corners = false;
    };
    "org/gnome/desktop/background" = {
      picture-uri = wallpaper;
      picture-uri-dark = wallpaper;
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      disable-while-typing = false; # Required for touchpad/keyboard games
      speed = 0.1;
      tap-to-click = false;
    };
    "org/gnome/desktop/privacy" = {
      remove-old-trash-files = true;
      old-files-age = lib.gvariant.mkUint32 1;
    };
    "org/gnome/desktop/wm/keybindings" = {
      toggle-fullscreen = [ "<Super>f" ];
      close = [ "<Super>q" ];
      switch-windows = [ "<Super>Tab" ];
      switch-windows-backward = [ "<Shift><Super>Tab" ];
      move-to-center = [ "<Super>c" ];
    };
    "org/gnome/desktop/app-folders".folder-children = [ "Game" ];
    "org/gnome/desktop/app-folders/folders/Game" = {
      name = "Game";
      categories = [ "Game" ];
    };
    "org/gnome/nautilus/icon-view".default-zoom-level = "medium";
    "org/gnome/nautilus/list-view".use-tree-view = true;
    "org/gnome/nautilus/preferences".show-delete-permanently = true;
    "org/gnome/settings-daemon/plugins/housekeeping".donation-reminder-enabled = false;
    "org/gnome/settings-daemon/plugins/power".power-button-action = "hibernate";
    "org/gnome/settings-daemon/plugins/media-keys".play = [ "<Shift><Super>F23" ];
    "org/gnome/evolution-data-server/calendar".notify-enable-audio = false; # Silences annoying daily beeps
  };
}
