{ pkgs }:
(import ./lib.nix).generate {
  inherit pkgs;
  fonts = {
    sans = {
      name = "DeepMind Sans";
      weight = "Medium";
      size = 11;
      package = pkgs.dm-sans;
      features = [ ];
    };
    serif = {
      name = "Libre Baskerville";
      size = 11;
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
  };
  colors = ./colors.json;
  icons = {
    name = "MoreWaita";
    package = pkgs.morewaita-icon-theme;
  };
  cursors = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
  };
  gnome = {
    scheme = "default";
    accent = "blue";
  };
}
