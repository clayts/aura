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
    runtimeEnv.ids = ./earthpaper/earthpaper.json;
    runtimeInputs = with pkgs; [
      jq
      curl
    ];
    text = builtins.readFile ./earthpaper/earthpaper.sh;
  };
  rizzlefetch = pkgs.python3Packages.buildPythonApplication {
    pname = "rizzlefetch";
    version = "0";
    pyproject = false;
    src = ./rizzlefetch.py;
    dontUnpack = true;
    dependencies = [ pkgs.python3Packages.terminaltexteffects ];
    installPhase = ''
      install -Dm755 $src $out/bin/rizzlefetch
    '';
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (pkgs.lib.makeBinPath [ pkgs.toilet ])
    ];
  };
}
