# Universe

## To Do
- rename data -> static?
- homeConfiguration = args: {...} to mirror nixosSystem = args: {...} in flake.nix, and sort out:
	```
	home = name: initialRelease: modules: {
      homeConfigurations = {
        ${name} = inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          useUserPackages = true;
          extraSpecialArgs = {inherit inputs;};
          modules = [./home-manager] ++ modules;
        };
      };
    };
	```
