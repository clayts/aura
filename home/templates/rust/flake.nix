{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = inputs: {
    devShells =
      let
        system = "x86_64-linux";
        pkgs = import inputs.nixpkgs { inherit system; };
      in
      {
        "${system}".default = pkgs.mkShell {
          packages = with pkgs; [
            nixd
            alejandra

            rustc
            cargo
            rustfmt
            clippy
            rust-analyzer
            pkg-config
          ];
        };
      };
  };
}
