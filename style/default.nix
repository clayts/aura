{ pkgs }:
{
  fonts = import ./fonts.nix { inherit pkgs; };
  colors =
    # x0-x7: greys, dark to light
    # x8 red, x9 yellow, xA orange, xB green, xC cyan, xD blue, xE purple, xF highlight
    builtins.fromJSON (builtins.readFile ./colors.json);
  icons = {
    name = "MoreWaita";
    package = pkgs.morewaita-icon-theme;
  };
  cursors = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
  };
}
