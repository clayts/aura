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
    runtimeInputs = [ pkgs.gocryptfs ];
    text = builtins.readFile ./safe.sh;
  };
  cloud = pkgs.writeShellApplication {
    name = "cloud";
    runtimeInputs = with pkgs; [
      # rclone 1.75.2's mount can show a file as empty, and keep doing so, if
      # its upload carries over a restart and its folder is listed before the
      # upload ends: the cache takes the listing's missing entry as proof the
      # file was deleted. Saving it then would overwrite it on Drive. This is
      # the fix from https://github.com/rclone/rclone/pull/9531 (issue #9530),
      # not yet merged; once a release has it, the patch fails to apply and
      # this override can go
      (rclone.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (fetchpatch {
            url = "https://github.com/rclone/rclone/commit/2754b9bc257a69229f0d8bc8eace6d1eed4c762f.patch";
            hash = "";
          })
        ];
      }))
      libsecret # secret-tool
      networkmanager # nmcli
      jq
    ];
    text = builtins.readFile ./cloud.sh;
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
  firefox-layout-version = pkgs.python3Packages.buildPythonApplication {
    pname = "firefox-layout-version";
    version = "0";
    pyproject = false;
    src = ./firefox-layout-version.py;
    dontUnpack = true;
    installPhase = ''
      install -Dm755 $src $out/bin/firefox-layout-version
    '';
    meta.mainProgram = "firefox-layout-version";
  };
  system = pkgs.writeShellApplication {
    name = "system";
    runtimeInputs = [
      pkgs.dix
      pkgs.git
    ];
    text = builtins.readFile ./system.sh;
  };
}
