{
  pkgs,
  assets,
  lib,
  config,
  ...
}:
{
  imports = [
    ./firefox.nix
    ./ghostty.nix
    ./gnome.nix
    ./micro.nix
    ./zeditor.nix
    ./zsh.nix
  ];
  home = {
    packages =
      let
        applications = with pkgs; [
          gnome-firmware
          loupe
          file-roller
          gnome-calculator
          gnome-characters
          gnome-logs
          gnome-clocks
          gnome-calendar
          eyedropper
          celluloid
          gitg
          papers
          impression
          baobab
          gnome-disk-utility
          nautilus
          nautilus-python
          yelp
          resources
          snapshot
          assets.packages.sabaki
          gnome-calendar
        ];
        fonts = with assets.style.fonts; [
          sans.package
          serif.package
          mono.package
          emoji.package
        ];
      in
      applications ++ fonts;
    sessionVariables = {
      EDITOR = "micro";
      GOPATH = "$HOME/.local/share/go";
      npm_config_cache = "$HOME/.cache/npm";
    };
    file = {
      "${config.xdg.userDirs.templates}".source = assets.templates;
    };
  };
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      templates = "${config.home.homeDirectory}/.Templates";
      publicShare = "${config.home.homeDirectory}/.Public";
      desktop = "${config.home.homeDirectory}/Desk";
      download = "${config.home.homeDirectory}/Desk";
      music = "${config.home.homeDirectory}/Media";
      pictures = "${config.home.homeDirectory}/Media";
      videos = "${config.home.homeDirectory}/Media";
      projects = "${config.home.homeDirectory}/Code";
      documents = "${config.home.homeDirectory}/Documents";
    };
    desktopEntries.cups = {
      name = "";
      noDisplay = true;
    };
    configFile."autostart/earthpaper.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Earthpaper
      Exec=${assets.packages.earthpaper}/bin/earthpaper
      X-GNOME-Autostart-enabled=true
      NoDisplay=true
    '';
  };
  fonts.fontconfig = {
    enable = true;
    defaultFonts = with assets.style.fonts; {
      sansSerif = [
        sans.name
        emoji.name
      ];
      serif = [
        serif.name
        emoji.name
      ];
      monospace = [
        mono.name
        emoji.name
      ];
      emoji = [
        emoji.name
        emoji.name
      ];
    };
    configFile.features = {
      enable = true;
      text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <description>Set features</description>
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              role: font:
              if font.features == [ ] then
                ""
              else
                ''
                  <match target="font">
                    <test name="family" compare="eq">
                      <string>${font.name}</string>
                    </test>
                    <edit name="fontfeatures" mode="append">
                      ${lib.concatMapStrings (f: "<string>${f} on</string>") font.features}
                    </edit>
                  </match>''
            ) assets.style.fonts
          )}
        </fontconfig>
      '';
    };
  };
}
