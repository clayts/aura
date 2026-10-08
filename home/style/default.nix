{ pkgs }:
let
  inherit (pkgs) lib;
in
{
  fonts = import ./fonts.nix { inherit pkgs; };
  colors =
    # x0-x7: greys, dark to light
    # x8 red, x9 yellow, xA orange, xB green, xC cyan, xD blue, xE purple, xF highlight
    builtins.fromJSON (builtins.readFile ./colors.json);
  # Darkens a "#rrggbb" colour towards black, keeping t of each channel
  darken =
    t: color:
    "#"
    +
      lib.concatMapStrings
        (
          i:
          lib.fixedWidthString 2 "0" (
            lib.toLower (
              lib.toHexString (builtins.floor (t * lib.fromHexString (builtins.substring i 2 color)))
            )
          )
        )
        [
          1
          3
          5
        ];
  icons = {
    name = "MoreWaita";
    package = pkgs.morewaita-icon-theme;
  };
  cursors = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
  };
}
