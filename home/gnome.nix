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
    packages.sabaki
    packages.earthpaper
    gnome-firmware
    file-roller
    eyedropper
    celluloid
    gitg
    impression
    mission-center
    proton-vpn
  ];
  # cloud mounts Google Drive at ~/.local/share/cloud, linked from ~/Cloud
  # (home/packages/cloud.sh), from login until the last session ends. Without
  # a config (cloud setup not run) it's skipped, not failed
  systemd.user.services.cloud =
    let
      # A crash leaves a dead mount ("Transport endpoint is not connected")
      # that stops rclone mounting again, and rclone can't unmount at stop
      # while files are open; a lazy unmount clears both
      unmount = "-/run/wrappers/bin/fusermount3 -uqz %h/.local/share/cloud";
    in
    {
      Unit = {
        Description = "Mount ~/Cloud from Google Drive";
        ConditionPathExists = "%h/.config/cloud.conf";
      };
      Service = {
        Type = "notify"; # rclone says when the mount is ready
        ExecStartPre = unmount;
        ExecStart = "${lib.getExe packages.cloud} mount";
        # ~/Cloud is a link, and gio follows it, so this sets the icon on the
        # mount's top folder; it's set once mounted, as the empty folder under
        # the mount isn't what Files shows (see folder-icons below)
        ExecStartPost = "-${lib.getExe' pkgs.glib "gio"} set %h/Cloud metadata::custom-icon-name folder-cloud";
        ExecStopPost = unmount;
        Restart = "on-failure";
        RestartSec = "30s";
      };
      Install.WantedBy = [ "default.target" ];
    };
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
        # v37 puts the panel at the bottom of the overview's stack, which is
        # harmless until GNOME 51 makes the overview's controls reactive: they
        # then sit over the panel and take its clicks. Upstream's fix is
        # unreleased; once a release has it, the patch fails to apply and this
        # override can go
        (just-perfection.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            # https://gitlab.gnome.org/jrahmatzadeh/just-perfection/-/work_items/309
            (pkgs.fetchpatch {
              name = "fix-panel-click-unresponsiveness-in-overview.patch";
              url = "https://gitlab.gnome.org/jrahmatzadeh/just-perfection/-/commit/625acf18af551c9a316035bd47a3926dfd5dc133.diff";
              relative = "src";
              hash = "sha256-r9bY0N0L2xXXUIcrU386FTAec4gTXRlxTUOeMoPy+SA=";
            })
          ];
        }))
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
  # Nautilus prefers a folder's custom icon, kept in its GIO metadata, to its
  # own choice; these are set at each login. Without them, Intake would get the
  # Desktop icon, as GLib checks for the desktop dir before downloads, and
  # Projects, which GLib doesn't treat as special, a plain folder icon. The
  # cloud service sets ~/Cloud's.
  xdg.configFile."autostart/folder-icons.desktop".text =
    let
      icons = {
        ${config.xdg.userDirs.download} = "folder-download";
        ${config.xdg.userDirs.projects} = "folder-code";
      };
      script = pkgs.writeShellScript "folder-icons" (
        lib.concatLines (
          lib.mapAttrsToList (
            dir: icon:
            "${lib.getExe' pkgs.glib "gio"} set ${lib.escapeShellArg dir} metadata::custom-icon-name ${icon}"
          ) icons
        )
      );
    in
    ''
      [Desktop Entry]
      Type=Application
      Name=Folder icons
      Exec=${script}
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
    "org/gnome/shell/extensions/appindicator".tray-pos = "left";
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
      play = [ "XF86Favorites" ];
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
