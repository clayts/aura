{ pkgs }:
(import ./lib.nix).generate {
  inherit pkgs;
  fonts = {
    sans = {
      name = "DeepMind Sans";
      weight = "Medium";
      size = 11;
      package = pkgs.dm-sans;
    };
    serif = {
      name = "Libre Baskerville";
      size = 11;
      package = pkgs.libre-baskerville;
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
    };
  };
  colors = ./colors.json;
  icons = {
    name = "MoreWaita";
    package = pkgs.morewaita-icon-theme;
  };
  cursors = rec {
    name = "Bibata-Modern-Classic";
    # GNOME Shell 51 draws cursors only from SVGs (a theme's cursors_scalable),
    # falling back to Adwaita's, and nixpkgs builds Bibata as X11 cursors only.
    # This is the theme as built, with SVG cursors made from Bibata's sources
    # alongside; the X11 cursors stay for apps that load cursors themselves
    package =
      pkgs.runCommand "bibata-cursors-scalable-${pkgs.bibata-cursors.version}"
        { nativeBuildInputs = [ pkgs.python3 ]; }
        ''
          theme=$out/share/icons/${name}
          mkdir -p $theme
          ln -s ${pkgs.bibata-cursors}/share/icons/${name}/* $theme
          python3 ${./bibata-scalable.py} ${pkgs.bibata-cursors.src} ${name} $theme/cursors_scalable
        '';
  };
  gnome = {
    scheme = "default";
    accent = "blue";
  };
}
