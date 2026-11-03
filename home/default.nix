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
  # luggage reads its config's key from the GNOME keyring, which is only
  # unlocked while logged in to GNOME, so it syncs only in the graphical
  # session: a minute after it starts, then 15 minutes after each sync ends.
  # Without a config (luggage setup not run) the sync is skipped, not failed
  systemd.user = {
    services.luggage = {
      Unit = {
        Description = "Sync ~/Library with Google Drive";
        Requisite = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionPathExists = "%h/.config/luggage.conf";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe packages.luggage} sync";
      };
    };
    timers.luggage = {
      Unit = {
        Description = "Sync ~/Library with Google Drive regularly";
        # Not After= the session: timers come before timers.target, which
        # comes before graphical-session.target, so that would be a cycle
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnActiveSec = "1min";
        OnUnitInactiveSec = "15min";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      templates = "${homeDirectory}/.Templates";
      publicShare = "${homeDirectory}/.Public";
      desktop = "${homeDirectory}/Desktop";
      download = "${homeDirectory}/Desktop";
      documents = "${homeDirectory}/Library";
      music = "${homeDirectory}/Library";
      pictures = "${homeDirectory}/Library";
      videos = "${homeDirectory}/Library";
      projects = "${homeDirectory}/Projects";
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
    configFile.style.text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        ${lib.concatMapStrings (font: ''
          ${lib.optionalString (font.features != [ ]) ''
            <match target="font">
              <test name="family"><string>${font.name}</string></test>
              <edit name="fontfeatures" mode="append">
                ${lib.concatMapStrings (feature: "<string>${feature} on</string>") font.features}
              </edit>
            </match>
          ''}
          ${lib.optionalString (font ? weight) ''
            <match target="pattern">
              <test name="family"><string>${font.name}</string></test>
              <test name="weight"><const>regular</const></test>
              <edit name="weight" mode="assign" binding="strong"><const>${lib.toLower font.weight}</const></edit>
            </match>
          ''}
        '') (lib.attrValues style.fonts)}
      </fontconfig>
    '';
  };
}
