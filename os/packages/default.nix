{
  inputs,
  pkgs,
}:
{
  install = pkgs.writeShellApplication {
    name = "install";
    runtimeEnv.flake = "${inputs.self}";
    runtimeInputs = [
      inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
      pkgs.git
      pkgs.toilet
    ];
    text = builtins.readFile ./install.sh;
  };
  system = pkgs.writeShellApplication {
    name = "system";
    runtimeInputs = [ pkgs.git ];
    text = builtins.readFile ./system.sh;
  };
  persist = pkgs.writers.writePython3Bin "persist" { } (builtins.readFile ./persist.py);
  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = [ pkgs.git ];
    text = builtins.readFile ./update.sh;
  };
}
