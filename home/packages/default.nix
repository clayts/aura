{ pkgs }:
let
  # The shell script ./<name>.sh
  script = args: pkgs.writeShellApplication ({ text = builtins.readFile ./${args.name}.sh; } // args);
in
{
  sabaki = import ./sabaki.nix { inherit pkgs; };
  sing = script {
    name = "sing";
    runtimeInputs = with pkgs; [
      yt-dlp
      jq
      (mpv.override { scripts = [ mpvScripts.mpris ]; })
    ];
  };
  create = pkgs.symlinkJoin {
    name = "create";
    paths = [
      (script {
        name = "create";
        # A flake.lock pinning nixpkgs to the system's
        runtimeEnv.lock =
          let
            systemLock = pkgs.lib.importJSON ../../flake.lock;
          in
          pkgs.writers.writeJSON "flake.lock" {
            nodes = {
              nixpkgs = systemLock.nodes.${systemLock.nodes.root.inputs.nixpkgs};
              root.inputs.nixpkgs = "nixpkgs";
            };
            root = "root";
            version = 7;
          };
        runtimeInputs = with pkgs; [
          git
          direnv
          go
          nodejs
          cargo
        ];
      })
      (pkgs.writeTextDir "share/zsh/site-functions/_create" (builtins.readFile ./_create))
    ];
  };
  safe = script {
    name = "safe";
    runtimeInputs = with pkgs; [
      gocryptfs
      util-linux
    ];
  };
  earthpaper = script {
    name = "earthpaper";
    runtimeEnv.ids = ./earthpaper.json;
    runtimeInputs = with pkgs; [
      jq
      curl
    ];
  };
  rizzlefetch = pkgs.writeShellApplication {
    name = "rizzlefetch";
    runtimeInputs = with pkgs; [
      toilet
      (python3.withPackages (ps: [ ps.terminaltexteffects ]))
    ];
    text = "exec python3 ${./rizzlefetch.py}";
  };
  preview = script {
    name = "preview";
    runtimeInputs = with pkgs; [
      bat
      lsd
      file
    ];
  };
  system = script {
    name = "system";
    runtimeInputs = with pkgs; [
      dix
      git
    ];
  };
}
