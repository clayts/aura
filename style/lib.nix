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
