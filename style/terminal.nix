{ pkgs, colors }:
let
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
{
  # Bright ANSI colours, as lighter versions of the normal ones
  bright = pkgs.lib.mapAttrs (_: lighten 0.3) (
    with colors;
    {
      red = x8;
      green = xB;
      yellow = xA;
      blue = xD;
      magenta = xE;
      cyan = xC;
    }
  );
}
