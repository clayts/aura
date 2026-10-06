{
  inputs,
  pkgs,
}:
{
  install = pkgs.writeShellApplication {
    name = "install";
    runtimeEnv.flake = "${inputs.self}";
    runtimeInputs = [
      # The CLI from the same disko as the module it reads the layout from
      inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
      pkgs.git
      pkgs.mkpasswd
      pkgs.toilet
    ];
    text = builtins.readFile ./install.sh;
  };
  system = pkgs.writeShellApplication {
    name = "system";
    runtimeInputs = [ pkgs.git ];
    text = builtins.readFile ./system.sh;
  };
  persist = pkgs.python3Packages.buildPythonApplication {
    pname = "persist";
    version = "0";
    pyproject = false;
    src = ./persist.py;
    dontUnpack = true;
    installPhase = ''
      install -Dm755 $src $out/bin/persist
    '';
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (pkgs.lib.makeBinPath [
        pkgs.fzf
        pkgs.grc
      ])
    ];
  };
}
