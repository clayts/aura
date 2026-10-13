{ style, ... }:
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
        foreground = grey5;
        cursor-color = grey5;
        selection-background = grey2;
        selection-foreground = grey5;
        palette = [
          "0=${grey0}"
          "1=${red}"
          "2=${green}"
          "3=${orange}"
          "4=${blue}"
          "5=${purple}"
          "6=${cyan}"
          "7=${grey5}"
          "8=${grey3}"
          "9=${bright.red}"
          "10=${bright.green}"
          "11=${bright.orange}"
          "12=${bright.blue}"
          "13=${bright.purple}"
          "14=${bright.cyan}"
          "15=${grey7}"
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
      window-padding-balance = true;
      confirm-close-surface = false;
      window-width = 80;
      window-height = 32;
    };
  };
}
