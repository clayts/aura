{ pkgs, ... }:
let
  style = import ./style { inherit pkgs; };
in
{
  # Lets GNOME run .desktop files that need a terminal in ghostty
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };

  programs.ghostty = {
    enable = true;
    themes = {
      "Custom" = with style.colors; {
        background = "#000000";
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
      font-family = with style.fonts; [
        mono.name
        emoji.name
      ];
      font-size = style.fonts.mono.size;
      adjust-cell-height = -2;
      font-feature = style.fonts.mono.features;
      theme = "Custom";
      palette-generate = true;
      command = "SHLVL=0; zsh";
      shell-integration = "zsh";
      shell-integration-features = "sudo";
      mouse-hide-while-typing = true;
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
