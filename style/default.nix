{ pkgs }:
{
  fonts = import ./fonts.nix { inherit pkgs; };
  colors =
    ## Terminal Color List
    # black
    # red
    # green
    # yellow
    # blue
    # purple
    # cyan
    # white
    # bright-black
    # bright-red
    # bright-green
    # bright-yellow
    # bright-blue
    # bright-purple
    # bright-cyan
    # bright-white
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
