{ pkgs }:
let
  katago-config = pkgs.writeText "config" ''
    logDir = /tmp/gtp_logs
    logAllGTPCommunication = true
    logSearchInfo = true
    logSearchInfoForChosenMove = false
    logToStderr = false
    rules = tromp-taylor
    allowResignation = true
    resignThreshold = -0.90
    resignConsecTurns = 3
    maxVisits = 500
    ponderingEnabled = false
    maxTimePondering = 60.0
    lagBuffer = 1.0
    numSearchThreads = 6
    searchFactorAfterOnePass = 0.50
    searchFactorAfterTwoPass = 0.25
    searchFactorWhenWinning = 0.40
    searchFactorWhenWinningThreshold = 0.95
  '';
  neural-network = pkgs.fetchurl {
    url = "https://media.katagotraining.org/uploaded/networks/models/kata1/kata1-zhizi-b28c512nbt-muonfd2.bin.gz";
    hash = "sha256-s3+aVqmxBRWaGW+bpyxTKHdvtc8wAUSV5NisilsHZUs=";
  };
  sabaki-unwrapped = pkgs.appimageTools.wrapType2 {
    pname = "sabaki";
    version = "0.52.2";

    src = pkgs.fetchurl {
      url = "https://github.com/SabakiHQ/Sabaki/releases/download/v0.52.2/sabaki-v0.52.2-linux-x64.AppImage";
      hash = "sha256-wuCj5HvNZc2KOdc5O49upNToFDKiMMWexykctHi51EY=";
    };
    extraPkgs = pkgs: with pkgs; [ libxshmfence ];
  };
  sabaki-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/SabakiHQ/Sabaki/950c5d9f6b4eeb0d9090aff6fe91c42b0221632e/logo.png";
    hash = "sha256-P5DKX+ecTCPN8p4D4BXeObP+TKSOc4Fi+sGmoJ6KLjw=";
  };
  sabaki-config = pkgs.writeText "settings.json" (
    builtins.toJSON {
      "engines.list" = [
        {
          name = "GnuGo";
          path = "${pkgs.gnugo}/bin/gnugo";
          args = "--mode gtp";
        }
        {
          name = "KataGo";
          path = "${pkgs.katagoCPU}/bin/katago";
          args = "gtp -model ${neural-network} -config ${katago-config}";
        }
      ];
      "view.show_menubar" = false;
    }
  );
  sabaki = pkgs.writeShellApplication {
    name = "sabaki";
    text = ''
      if [[ ! -d "$XDG_CONFIG_HOME/Sabaki" ]]; then
        mkdir -p "$XDG_CONFIG_HOME/Sabaki"
        cat ${sabaki-config} > "$XDG_CONFIG_HOME/Sabaki/settings.json"
      fi
      ${sabaki-unwrapped}/bin/sabaki "$@"
    '';
  };
  sabaki-desktop = pkgs.makeDesktopItem {
    name = "sabaki";
    desktopName = "Sabaki";
    exec = "sabaki %U";
    icon = "sabaki";
    comment = "Elegant goban";
    categories = [ "Game" ];
  };
in
(pkgs.symlinkJoin {
  name = "sabaki";
  paths = [
    sabaki
    sabaki-desktop
  ];
  postBuild = ''
    install -Dm644 ${sabaki-icon} \
      $out/share/icons/hicolor/256x256/apps/sabaki.png
  '';
})
