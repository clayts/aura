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
# Base16's colours by name: grey0-grey7 are base00-base07, dark to light,
# then red, orange, yellow, green, cyan, blue, purple and brown are base08-base0F
colors
// {
  # Lighter versions of each colour, e.g. for bright terminal colours
  bright = pkgs.lib.mapAttrs (_: lighten 0.3) colors;
}
