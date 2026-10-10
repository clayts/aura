{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    firefox-theme = {
      url = "github:rafaelmardojai/firefox-gnome-theme/master";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
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
    in
    {
      nixosConfigurations.aura = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./os
          { nixpkgs.pkgs = pkgs; }
        ];
      };
      packages.${system}.install =
        let
          inherit (inputs.self.nixosConfigurations.aura) config;
          luks = config.disko.devices.disk.main.content.partitions.luks.content;
        in
        pkgs.writeShellApplication {
          name = "install";
          runtimeEnv = {
            flake = "${inputs.self}";
            # The commit to check out in /etc/nixos, so it matches what was installed
            rev = inputs.self.rev or "";
            disk = config.disko.devices.disk.main.device;
            diskPassword = luks.passwordFile;
            tpmKey = builtins.head luks.additionalKeyFiles;
            installedTpmKey = config.systemd.services.tpm-enroll.environment.KEY;
            pkiBundle = config.boot.lanzaboote.pkiBundle;
            esp = config.boot.loader.efi.efiSysMountPoint;
          };
          runtimeInputs = [
            # The CLI from the same disko as the module it reads the layout from
            inputs.disko.packages.${system}.disko
            # The installer's own may predate OPAL support
            pkgs.cryptsetup
            pkgs.git
            pkgs.mkpasswd
            pkgs.sbctl
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
          package-version-server
          basedpyright
          ruff
          (python3.withPackages (ps: [ ps.terminaltexteffects ]))
        ];
      };
    };
}
