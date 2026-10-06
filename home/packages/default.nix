{ pkgs }:
{
  sabaki = import ./sabaki.nix { inherit pkgs; };
  sing = pkgs.writeShellApplication {
    name = "sing";
    runtimeInputs = with pkgs; [
      yt-dlp
      jq
      (mpv.override { scripts = [ mpvScripts.mpris ]; })
    ];
    text = builtins.readFile ./sing.sh;
  };
  safe = pkgs.writeShellApplication {
    name = "safe";
    runtimeInputs = with pkgs; [
      gocryptfs
      util-linux
    ];
    text = builtins.readFile ./safe.sh;
  };
  earthpaper = pkgs.writeShellApplication {
    name = "earthpaper";
    runtimeEnv.ids = ./earthpaper.json;
    runtimeInputs = with pkgs; [
      jq
      curl
    ];
    text = builtins.readFile ./earthpaper.sh;
  };
  rizzlefetch = pkgs.writers.writePython3Bin "rizzlefetch" {
    libraries = ps: [ ps.terminaltexteffects ];
    # Replaces flake8's default ignores; W503 clashes with ruff's line breaks
    flakeIgnore = [
      "E501"
      "W503"
    ];
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (pkgs.lib.makeBinPath [ pkgs.toilet ])
    ];
  } (builtins.readFile ./rizzlefetch.py);
}
