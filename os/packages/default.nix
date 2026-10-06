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
  persist = pkgs.writers.writePython3Bin "persist" {
    flakeIgnore = [ "E501" ]; # ruff formats to 88 columns, flake8 checks 79
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (pkgs.lib.makeBinPath [
        pkgs.fzf
        pkgs.grc
      ])
    ];
  } (builtins.readFile ./persist.py);
}
