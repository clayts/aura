{ lib }:
let
  # Applies f to each channel of a "#rrggbb" colour, as a number from 0 to 255
  mapChannels =
    f: color:
    "#"
    +
      lib.concatMapStrings
        (
          i:
          lib.fixedWidthString 2 "0" (
            lib.toLower (
              lib.toHexString (builtins.floor (f (lib.fromHexString (builtins.substring i 2 color))))
            )
          )
        )
        [
          1
          3
          5
        ];
in
{
  # Darkens a colour towards black, keeping t of each channel
  darken = t: mapChannels (c: t * c);
  # Lightens a colour towards white, closing t of the gap to it
  lighten = t: mapChannels (c: c + t * (255 - c));
  # A font as GNOME names it, e.g. "DeepMind Sans Medium 11"
  fontName =
    font:
    lib.concatStringsSep " " (
      [ font.name ] ++ lib.optional (font ? weight) font.weight ++ [ (toString font.size) ]
    );
}
