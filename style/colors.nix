{ pkgs }:
let
  colors = builtins.fromJSON (builtins.readFile ./colors.json);
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
colors // { bright = pkgs.lib.mapAttrs (_: lighten 0.3) colors; }
