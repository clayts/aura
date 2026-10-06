{ pkgs }:
{
  sabaki = import ./sabaki.nix { inherit pkgs; };
  sing = pkgs.writeShellApplication {
    name = "sing";
    runtimeEnv = {
      mpris = pkgs.mpvScripts.mpris;
    };
    runtimeInputs = with pkgs; [
      yt-dlp
      jq
      mpv
    ];
    text = builtins.readFile ./sing.sh;
  };
  safe = pkgs.writeShellApplication {
    name = "safe";
    runtimeInputs = with pkgs; [ gocryptfs ];
    text = builtins.readFile ./safe.sh;
  };
  earthpaper = pkgs.writeShellApplication {
    name = "earthpaper";
    runtimeInputs = with pkgs; [
      jq
      curl
      dconf
    ];
    text = builtins.readFile ./earthpaper.sh;
  };
  rizzlefetch = pkgs.writeShellApplication {
    name = "rizzlefetch";
    runtimeInputs = with pkgs; [
      toilet
      (python313.withPackages (ps: with ps; [ terminaltexteffects ]))
    ];
    text = ''
      python ${./rizzlefetch.py}
    '';
  };
}
