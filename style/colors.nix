{ pkgs }:
let
  colors = builtins.fromJSON (builtins.readFile ./colors.json);
  # Lightens a "#rrggbb" colour towards white, closing t of the gap to it
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
in
# Base16: base00-base07 greys, dark to light
# base08 red, base09 orange, base0A yellow, base0B green, base0C cyan, base0D blue, base0E purple, base0F brown
colors
// {
  # Lighter versions of each colour, e.g. for bright terminal colours
  bright = pkgs.lib.mapAttrs (_: lighten 0.3) colors;
}
