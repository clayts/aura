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
  create =
    let
      systemLock = builtins.fromJSON (builtins.readFile ../../flake.lock);
      lock = (pkgs.formats.json { }).generate "flake.lock" {
        nodes = {
          nixpkgs = systemLock.nodes.${systemLock.nodes.root.inputs.nixpkgs};
          root.inputs.nixpkgs = "nixpkgs";
        };
        root = "root";
        version = 7;
      };
    in
    pkgs.symlinkJoin {
      name = "create";
      paths = [
        (pkgs.writeShellApplication {
          name = "create";
          runtimeEnv = {
            templates = ./create;
            inherit lock;
          };
          runtimeInputs = with pkgs; [
            git
            direnv
            go
            nodejs
            cargo
          ];
          text = builtins.readFile ./create/create.sh;
        })
        (pkgs.writeTextDir "share/zsh/site-functions/_create" (builtins.readFile ./create/_create))
      ];
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
  preview = pkgs.writeShellApplication {
    name = "preview";
    runtimeInputs = with pkgs; [
      bat
      lsd
      file
    ];
    text = builtins.readFile ./preview.sh;
  };
  system = pkgs.writeShellApplication {
    name = "system";
    runtimeInputs = [ pkgs.git ];
    text = builtins.readFile ./system.sh;
  };
}
