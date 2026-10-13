{
  lib,
  fonts,
  icons,
  cursors,
}:
{
  # Interface settings, shared by each user and GDM
  interface =
    let
      # A font as GNOME names it, e.g. "DeepMind Sans Medium 11"
      fontName =
        font:
        lib.concatStringsSep " " (
          [ font.name ] ++ lib.optional (font ? weight) font.weight ++ [ (toString font.size) ]
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
