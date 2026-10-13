{
  pkgs,
  lib,
  config,
  style,
  ...
}:
let
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
  # Shared with every module here as arguments
  _module.args = { inherit packages; };
  home = {
    stateVersion = "26.11";
    preferXdgDirectories = true;
    sessionVariables = {
      EDITOR = "micro";
      GOPATH = "$HOME/.local/share/go";
      CARGO_HOME = "$HOME/.local/share/cargo";
      npm_config_cache = "$HOME/.cache/npm";
    };
    file."${config.xdg.userDirs.templates}".source = ./templates;
  };
  xdg = {
    enable = true;
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
    configFile.weights.text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <description>Set default weights</description>
        ${lib.concatMapStrings (
          font:
          lib.optionalString (font ? weight) ''
            <match target="pattern">
              <test name="family" compare="eq">
                <string>${font.name}</string>
              </test>
              <test name="weight" compare="eq">
                <const>regular</const>
              </test>
              <edit name="weight" mode="assign" binding="strong">
                <const>${lib.toLower (lib.replaceStrings [ "-" " " ] [ "" "" ] font.weight)}</const>
              </edit>
            </match>
          ''
        ) fonts}
      </fontconfig>
    '';
  };
}
