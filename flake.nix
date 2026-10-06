{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-theme = {
      url = "github:rafaelmardojai/firefox-gnome-theme/master";
      flake = false;
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      style = import ./home/style { inherit pkgs; };
      packages = {
        os = import ./os/packages { inherit pkgs; };
        home = import ./home/packages { inherit pkgs; };
      };
    in
    {
      nixosConfigurations.aura = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs style packages; };
        modules = [
          ./os
          { nixpkgs.pkgs = pkgs; }
        ];
      };
      packages.${system}.install = pkgs.writeShellApplication {
        name = "install";
        runtimeEnv.flake = "${inputs.self}";
        runtimeInputs = [
          # The CLI from the same disko as the module it reads the layout from
          inputs.disko.packages.${system}.disko
          pkgs.git
          pkgs.mkpasswd
          pkgs.toilet
        ];
        text = builtins.readFile ./install.sh;
      };
      formatter.${system} = pkgs.nixfmt-tree;
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixd
          nixfmt
          shellcheck
          vscode-langservers-extracted
          basedpyright
          ruff
          (python3.withPackages (ps: [ ps.terminaltexteffects ]))
        ];
      };
    };
}
