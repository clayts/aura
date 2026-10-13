{ pkgs }:
rec {
  fonts = {
    sans = {
      name = "DeepMind Sans";
      weight = "Medium";
      size = 11;
      package = pkgs.dm-sans;
      features = [ ];
    };
    serif = {
      name = "Libre Baskerville";
      size = 11;
      package = pkgs.libre-baskerville;
      features = [ ];
    };
    mono = {
      name = "Maple Mono NF";
      size = 10;
      package = pkgs.maple-mono.NF;
      features = [
        "calt"
        "cv02"
        "cv01"
        "cv65"
        "cv66"
        "ss03"
        "ss06"
        "ss11"
      ];
    };
    emoji = {
      name = "Noto Color Emoji";
      size = 10;
      package = pkgs.noto-fonts-color-emoji;
      features = [ ];
    };
  };
  colors =
    # x0-x7: greys, dark to light
    # x8 red, x9 yellow, xA orange, xB green, xC cyan, xD blue, xE purple, xF highlight
    builtins.fromJSON (builtins.readFile ./colors.json);
  icons = {
    name = "MoreWaita";
    package = pkgs.morewaita-icon-theme;
  };
  cursors = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
  };
  # GNOME's interface settings, shared by each user and GDM
  gnomeInterface =
    let
      # A font as GNOME names it, e.g. "DeepMind Sans Medium 11"
      fontName =
        font:
        pkgs.lib.concatStringsSep " " (
          [ font.name ] ++ pkgs.lib.optional (font ? weight) font.weight ++ [ (toString font.size) ]
        );
    in
    {
      font-name = fontName fonts.sans;
      document-font-name = fontName fonts.serif;
      monospace-font-name = fontName fonts.mono;
      icon-theme = icons.name;
      cursor-theme = cursors.name;
      color-scheme = "default";
      accent-color = "blue";
    };
}
