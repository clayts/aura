{
  pkgs,
  lib,
  config,
  style,
  packages,
  ...
}:
let
  wallpaper = "${config.xdg.dataHome}/earthpaper/image.jpeg";
  blankWallpaper = pkgs.runCommand "blank-wallpaper.jpeg" { } ''
    ${lib.getExe' pkgs.imagemagick "magick"} -size 1920x1200 'gradient:${style.colors.grey1}-${style.colors.grey0}' $out
  '';
in
{
  home.packages = with pkgs; [
    gnome-firmware
    file-roller
    eyedropper
    celluloid
    gitg
    impression
    mission-center
    packages.sabaki
    packages.earthpaper
  ];
  gtk = {
    enable = true;
    iconTheme = style.icons;
    gtk3.theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
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
        preserve-battery-health
      ]
    );
  };
  home.activation.earthpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e ${lib.escapeShellArg wallpaper} ]]; then
      run install -D -m 644 ${blankWallpaper} ${lib.escapeShellArg wallpaper}
    fi
  '';
  xdg.configFile."autostart/earthpaper.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Earthpaper
    Exec=${lib.getExe packages.earthpaper} ${wallpaper}
    X-GNOME-Autostart-enabled=true
    NoDisplay=true
  '';
  xdg.configFile."autostart/projects-icon.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Projects folder icon
    Exec=${lib.getExe' pkgs.glib "gio"} set ${config.xdg.userDirs.projects} metadata::custom-icon-name folder-code
    X-GNOME-Autostart-enabled=true
    NoDisplay=true
  '';
  xdg.desktopEntries = {
    "org.gnome.Extensions" = {
      name = "Extensions";
      noDisplay = true;
    };
    "cups" = {
      name = "Cups";
      noDisplay = true;
    };
    "btop" = {
      name = "btop++";
      noDisplay = true;
    };
  };
  dconf.settings = {
    "org/gnome/shell".favorite-apps = [
      "firefox.desktop"
      "org.gnome.Nautilus.desktop"
    ];
    "org/gnome/settings-daemon/plugins/power" = {
      ambient-enabled = false;
      power-button-action = "suspend";
    };
    "org/gnome/shell/extensions/auto-power-profile".bat = "power-saver";
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
    "org/gnome/desktop/interface" = style.gnome.interface // {
      gtk-enable-primary-paste = false;
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
    "org/gtk/gtk4/settings/file-chooser".sort-directories-first = true;
    "org/gtk/settings/file-chooser".sort-directories-first = true;
    "org/gnome/nautilus/icon-view".default-zoom-level = "medium";
    "org/gnome/nautilus/list-view".use-tree-view = true;
    "org/gnome/nautilus/preferences".show-delete-permanently = true;
    "org/gnome/settings-daemon/plugins/housekeeping".donation-reminder-enabled = false;
    "org/gnome/settings-daemon/plugins/media-keys" = {
      play = [ "<Shift><Super>F23" ];
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal" = {
      name = "Terminal";
      binding = "<Super>Return";
      command = "ghostty +new-window";
    };
    "org/gnome/evolution-data-server/calendar".notify-enable-audio = false; # Silences annoying daily beeps
    "io/missioncenter/MissionCenter" = {
      first-time-running = false;
      performance-show-fans = false;
      apps-page-merged-process-stats = true;
      performance-smooth-graphs = true;
      performance-sliding-graphs = true;
      apps-page-core-count-affects-percentages = true;
    };
  };
}
