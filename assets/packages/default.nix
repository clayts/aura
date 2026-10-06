{
  inputs,
  pkgs,
}:
let
  systemRelease = inputs.nixpkgs.lib.trivial.release;
  homeRelease = (builtins.fromJSON (builtins.readFile "${inputs.home-manager}/release.json")).release;
in
rec {
  sabaki = import ./sabaki.nix { inherit pkgs; };
  scan = pkgs.writeShellApplication {
    name = "scan";
    runtimeInputs = with pkgs; [
      nixos-facter
      jq
    ];
    text = builtins.readFile ./scan.sh;
  };
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
  install-system = pkgs.writeShellApplication {
    name = "install-system";
    runtimeEnv = { inherit systemRelease homeRelease; };
    runtimeInputs = [
      scan
      pkgs.toilet
    ];
    text = builtins.readFile ./install-system.sh;
  };
  install-home = pkgs.writeShellApplication {
    name = "install-home";
    runtimeEnv = { inherit homeRelease; };
    runtimeInputs = [ ];
    text = builtins.readFile ./install-home.sh;
  };
  system = pkgs.writeShellApplication {
    name = "system";
    text = builtins.readFile ./system.sh;
  };
  persist = pkgs.writers.writePython3Bin "persist" { } (builtins.readFile ./persist.py);
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
  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = [ pkgs.git ];
    text = builtins.readFile ./update.sh;
  };
}
