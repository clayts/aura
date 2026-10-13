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
      palette = builtins.fromJSON (builtins.readFile colors);
      lighten =
        t: color:
        "#"
        +
          pkgs.lib.concatMapStrings
            (
              i:
              let
                c = pkgs.lib.fromHexString (builtins.substring i 2 color);
              in
              pkgs.lib.fixedWidthString 2 "0" (
                pkgs.lib.toLower (pkgs.lib.toHexString (builtins.floor (c + t * (255 - c))))
              )
            )
            [
              1
              3
              5
            ];
      # A font as GNOME names it, e.g. "DeepMind Sans Medium 11"
      fontName =
        font:
        pkgs.lib.concatStringsSep " " (
          [ font.name ] ++ pkgs.lib.optional (font ? weight) font.weight ++ [ (toString font.size) ]
        );
    in
    {
      inherit fonts icons cursors;
      colors = palette // {
        bright = pkgs.lib.mapAttrs (_: lighten 0.3) palette;
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
