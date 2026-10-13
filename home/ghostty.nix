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
        foreground = base05;
        cursor-color = base05;
        selection-background = base02;
        selection-foreground = base05;
        palette = [
          "0=${base00}"
          "1=${base08}"
          "2=${base0B}"
          "3=${base0A}"
          "4=${base0D}"
          "5=${base0E}"
          "6=${base0C}"
          "7=${base05}"
          "8=${base03}"
          "9=${bright.base08}"
          "10=${bright.base0B}"
          "11=${bright.base0A}"
          "12=${bright.base0D}"
          "13=${bright.base0E}"
          "14=${bright.base0C}"
          "15=${base07}"
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
