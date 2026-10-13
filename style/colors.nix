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
# x0-x7: greys, dark to light
# x8 red, x9 yellow, xA orange, xB green, xC cyan, xD blue, xE purple, xF highlight
colors
// {
  # Lighter versions of each colour, e.g. for bright terminal colours
  bright = pkgs.lib.mapAttrs (_: lighten 0.3) colors;
}
