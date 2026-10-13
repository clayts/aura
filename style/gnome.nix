{
  pkgs,
  fonts,
  icons,
  cursors,
  scheme,
  accent,
}:
{
  interface =
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
      color-scheme = scheme;
      accent-color = accent;
    };
}
