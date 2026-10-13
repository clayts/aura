{ lib }:
{
  # A font as GNOME names it, e.g. "DeepMind Sans Medium 11"
  fontName =
    font:
    lib.concatStringsSep " " (
      [ font.name ] ++ lib.optional (font ? weight) font.weight ++ [ (toString font.size) ]
    );
}
