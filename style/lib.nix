{
  generate =
    {
      pkgs,
      fonts,
      colors,
      icons,
      cursors,
      gnome,
    }:
    let
      inherit (pkgs) lib;
      palette = lib.importJSON colors;
      # Applies f to each channel of a "#rrggbb" colour
      mapChannels =
        f: color:
        let
          channel =
            i:
            lib.fixedWidthString 2 "0" (
              lib.toLower (
                lib.toHexString (builtins.floor (f (lib.fromHexString (builtins.substring i 2 color))))
              )
            );
        in
        "#${channel 1}${channel 3}${channel 5}";
      # Moves a colour t of the way towards white
      lighten = t: mapChannels (c: c + t * (255 - c));
      # Keeps t of a colour, darkening it towards black
      darken = t: mapChannels (c: t * c);
      # A font as GNOME names it, e.g. "DeepMind Sans Medium 11"
      fontName =
        font:
        lib.concatStringsSep " " (
          [ font.name ] ++ lib.optional (font ? weight) font.weight ++ [ (toString font.size) ]
        );
    in
    {
      inherit icons cursors darken;
      fonts = lib.mapAttrs (_: font: { features = [ ]; } // font) fonts;
      colors = palette // {
        bright = lib.mapAttrs (_: lighten 0.3) palette;
        # GNOME's accent colour as libadwaita shows it on its own (text, icons)
        # against a dark background: the accent's own colour, adw_accent_color_to_rgba,
        # with its OKLab lightness raised to at least 0.85, adw_rgba_to_standalone
        accent =
          {
            blue = "#81d0ff"; # #3584e4
            teal = "#7bdff4"; # #2190a4
            green = "#8de698"; # #3a944a
            yellow = "#ffc057"; # #c88800
            orange = "#ff9c5b"; # #ed5b00
            red = "#ff888c"; # #e62d42
            pink = "#ffa0d8"; # #d56199
            purple = "#fba7ff"; # #9141ac
            slate = "#bbd1e5"; # #6f8396
          }
          .${gnome.accent};
      };
      gnome.interface = {
        font-name = fontName fonts.sans;
        document-font-name = fontName fonts.serif;
        monospace-font-name = fontName fonts.mono;
        icon-theme = icons.name;
        cursor-theme = cursors.name;
        color-scheme = gnome.scheme;
        accent-color = gnome.accent;
      };
    };
}
