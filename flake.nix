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
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        nixpkgs.follows = "";
        home-manager.follows = "";
      };
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
      style = import ./style { inherit pkgs; };
      packages = {
        os = import ./os/packages { inherit inputs pkgs; };
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
      apps.${system}.install = {
        type = "app";
        program = "${packages.os.install}/bin/install";
      };
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixd
          nixfmt

          color-lsp

          package-version-server

          vscode-langservers-extracted

          superhtml
          basedpyright
          ruff
          (python313.withPackages (ps: with ps; [ terminaltexteffects ]))

          packages.os.update
        ];
      };
    };
}
