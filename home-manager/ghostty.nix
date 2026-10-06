{
  pkgs,
  assets,
  ...
}:
{
  # This allows gnome to use ghostty as a default terminal when running
  # .desktop files that require a terminal
  home.packages = [ (pkgs.writeShellScriptBin "xterm" "${pkgs.ghostty} $*") ];

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    systemd.enable = true;
    themes = {
      "Custom" = with assets.style.colors; {
        background = x9;
        foreground = x5;
        cursor-color = x5;
        selection-background = x2;
        selection-foreground = x5;
        palette = [
          "0=${x0}"
          "1=${x8}"
          "2=${xB}"
          "3=${xA}"
          "4=${xD}"
          "5=${xE}"
          "6=${xC}"
          "7=${x5}"
          "8=${x3}"
          "9=${x8}"
          "10=${xB}"
          "11=${xA}"
          "12=${xD}"
          "13=${xE}"
          "14=${xC}"
          "15=${x7}"
        ];
      };
    };
    settings = {
      keybind = [
        "performable:ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
      ];
      font-family = with assets.style.fonts; [
        mono.name
        emoji.name
      ];
      font-size = assets.style.fonts.mono.size;
      adjust-cell-height = -2;
      font-feature = assets.style.fonts.mono.features;
      theme = "Custom";
      background = "000000";
      command = "SHLVL=0; zsh";
      window-theme = "ghostty";
      gtk-toolbar-style = "flat";
      window-padding-x = 9;
      window-padding-y = 3;
      confirm-close-surface = false;
      window-width = 80;
      window-height = 32;
    };
  };
}
