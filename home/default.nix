{
  pkgs,
  lib,
  config,
  ...
}:
let
  style = import ./style { inherit pkgs; };
  packages = import ./packages { inherit pkgs; };
  homeDirectory = config.home.homeDirectory;
  fonts = lib.attrValues style.fonts;
in
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
    stateVersion = "26.11";
    packages = map (font: font.package) fonts;
    sessionVariables = {
      EDITOR = "micro";
      GOPATH = "$HOME/.local/share/go";
      CARGO_HOME = "$HOME/.local/share/cargo";
      npm_config_cache = "$HOME/.cache/npm";
    };
    file = {
      "${config.xdg.userDirs.templates}" = {
        source = ./templates/files;
        recursive = true;
      };
      # Hidden, so Nautilus doesn't list it among file templates
      "${config.xdg.userDirs.templates}/.Folders".source = ./templates/folders;
    };
  };
  xdg = {
    enable = true;
    dataFile."nautilus-python/extensions/folder-templates.py".source = packages.folder-templates;
    userDirs = {
      enable = true;
      createDirectories = true;
      templates = "${homeDirectory}/.Templates";
      publicShare = "${homeDirectory}/.Public";
      desktop = "${homeDirectory}/Desk";
      download = "${homeDirectory}/Desk";
      music = "${homeDirectory}/Media";
      pictures = "${homeDirectory}/Media";
      videos = "${homeDirectory}/Media";
      projects = "${homeDirectory}/Code";
      documents = "${homeDirectory}/Documents";
    };
  };
  fonts.fontconfig = {
    defaultFonts = with style.fonts; {
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
      emoji = [ emoji.name ];
    };
    configFile.features.text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <description>Set features</description>
        ${lib.concatMapStrings (
          font:
          lib.optionalString (font.features != [ ]) ''
            <match target="font">
              <test name="family" compare="eq">
                <string>${font.name}</string>
              </test>
              <edit name="fontfeatures" mode="append">
                ${lib.concatMapStrings (feature: "<string>${feature} on</string>") font.features}
              </edit>
            </match>
          ''
        ) fonts}
      </fontconfig>
    '';
  };
}
