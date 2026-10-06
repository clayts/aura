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
      pkgs = import inputs.nixpkgs { inherit system; };
      assets = import ./assets { inherit inputs pkgs; };
    in
    {
      apps.${system} = {
        install-system = {
          type = "app";
          program = "${assets.packages.install-system}/bin/install-system";
        };
        install-home = {
          type = "app";
          program = "${assets.packages.install-home}/bin/install-home";
        };
      };
      nixosSystem =
        {
          name,
          foundation,
          hardware,
          imports ? [ ],
          specialArgs ? { },
        }:
        {
          nixosConfigurations = {
            "${name}" = inputs.nixpkgs.lib.nixosSystem {
              specialArgs = {
                inherit inputs assets;
              }
              // specialArgs;
              modules = [
                {
                  networking.hostName = "${name}";
                  system.stateVersion = "${foundation.system}";
                  home-manager.sharedModules = [ { home.stateVersion = "${foundation.homes}"; } ];
                  imports = [
                    ./nixos
                    hardware
                  ]
                  ++ imports;
                }
              ];
            };
          };
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

          assets.packages.update
        ];
      };
    };
}
