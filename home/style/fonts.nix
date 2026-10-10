{ pkgs }:
{
  sans = {
    name = "DeepMind Sans";
    # Optional, for a family whose default weight should be other than
    # Regular, e.g. "Light", "Medium" or "Semi-Bold". Naming a weight's own
    # family instead, like "DeepMind Sans Medium", would leave bold text to be
    # faked by thickening that weight
    weight = "Medium";
    size = 11;
    package = pkgs.dm-sans;
    features = [ ];
  };
  serif = {
    name = "Libre Baskerville";
    size = 10;
    package = pkgs.libre-baskerville;
    features = [ ];
  };
  mono = {
    name = "Maple Mono NF";
    size = 10;
    package = pkgs.maple-mono.NF;
    features = [
      "calt"
      "cv02"
      "cv01"
      "cv65"
      "cv66"
      "ss03"
      "ss06"
      "ss11"
    ];
  };
  emoji = {
    name = "Noto Color Emoji";
    size = 10;
    package = pkgs.noto-fonts-color-emoji;
    features = [ ];
  };
}
