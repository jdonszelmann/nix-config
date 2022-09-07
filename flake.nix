{
  description = "yo";
  nixConfig = {
    bash-prompt = "\[config\]$ ";
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://rrbutani.cachix.org"
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "rrbutani.cachix.org-1:FUpcK9RyZjjdOm8qherJl9+wfTGf6ptANvH6LZF63Ro="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    darwin = {
      url = github:lnl7/nix-darwin/master;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = github:nix-community/home-manager/master;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ragenix = {
      url = github:yaxitech/ragenix;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = github:nix-community/impermanence/master;
    nixos-hardware.url = github:rrbutani/nixos-hardware/master; # TODO: switch back to upstream!
    flu.url = github:numtide/flake-utils;
  };

  outputs = flakeInputs@{ self, nixpkgs, darwin, home-manager, flu, ... }: let
    dir = import ./util/list-dir.nix { lib = nixpkgs.lib; };
    util = dir { of = ./util; mapFunc = _: import; };
    inputs = flakeInputs // { inherit util; };

    conditionallyProvideInputs = func: inputs:
      if builtins.isFunction func && (builtins.functionArgs func) != {} then
        func inputs
      else func;
    mapFunc = _: inpPath: conditionallyProvideInputs (import inpPath) inputs;
    defaultFunc = mapFunc;

    list = [
      # Outputs tagged with a `<system>`:
      (flu.lib.eachDefaultSystem (sys: {
        # TODO: do we have other checks? packages? etc
        checks = with nixpkgs.lib; let
          tagAndExtract = { tag, ex }: mapAttrs'
            (n: v: {
              name = "${tag}/${n}";
              value = ex v;
            })
            self."${tag}Configurations"
          ;
          drvs =
            (tagAndExtract { tag = "nixos"; ex = d: d.config.system.build.toplevel; }) //
            (tagAndExtract { tag = "darwin"; ex = d: d.system; }) //
            (tagAndExtract { tag = "home"; ex = d: d.activationPackage; });
        in
          filterAttrs (n: v: v.system == sys) drvs;

        # TODO: packages: ./packages
        # TODO: apps: getExe + ./packages?

        # TODO: devShells?
      }))

      /* nixpkgs overlays */
      { overlays = dir { of = ./overlays; inherit mapFunc; }; }

      /* NixOS stuff */
      { nixosModules = dir {
        of = ./modules/nixos;
        recurse = true;
        mapFunc = _: import;
      }; }
      { nixosConfigurations = dir {
        of = ./machines;
        includeFilesWithExtension = null;
        includeDirsWithFile = "nixos.nix";

        # Always make the flake inputs accessible to modules via `specialArgs`:
        # https://nixos.wiki/wiki/Flakes#Using_nix_flakes_with_NixOS
        mapFunc = n: v: let
          config = defaultFunc n v;
          config' = config // {
            specialArgs =
              { inherit (config) system; configName = n; } //
              inputs // config.specialArgs or {};
          };
        in
          nixpkgs.lib.nixosSystem config';
      }; }

      /* Darwin stuff */
      { darwinModules = dir {
        of = ./modules/darwin;
        recurse = true;
        mapFunc = _: import;
      }; }
      { darwinConfigurations = dir {
        of = ./machines;
        includeFilesWithExtension = null;
        includeDirsWithFile = "darwin.nix";

        # Always make the flake inputs accessible to modules via `inputs`:
        # https://github.com/LnL7/nix-darwin#flakes-experimental
        mapFunc = n: v: let
          config = defaultFunc n v;
          config' = config // {
            inputs =
              { inherit (config) system; configName = n; } //
              inputs // config.inputs or {};
            };
        in
          darwin.lib.darwinSystem config';
      }; }

      /* home-manager stuff */
      # TODO: home-manager module key name? See: https://github.com/nix-community/home-manager/issues/1783
      { homeModules = dir {
        of = ./modules/home-manager;
        recurse = true;
        mapFunc = _: import;
      }; }
      { homeConfigurations = dir {
        of = ./machines;
        recurse = true;
        includeFilesWithExtension = "home.nix";
        includeDirsWithFile = "home.nix";

        # Always make the flake inputs accessible to modules via `extraSpecialArgs`:
        # https://github.com/nix-community/home-manager/blob/5bd66dc6cd967033489c69d486402b75d338eeb6/templates/standalone/flake.nix#L13-L28
        mapFunc = n: v: let
          config = defaultFunc n v;
          pkgs = nixpkgs.legacyPackages.${config.system};
          config' =
            (nixpkgs.lib.filterAttrs (n: _: n != "system") config) // { inherit pkgs; } //

            # Prepend to `extraSpecialArgs`:
            {
              extraSpecialArgs =
                { inherit (config) system; configName = n; } //
                inputs // config.extraSpecialArgs or {};
            };
          in
            home-manager.lib.homeManagerConfiguration config';
      }; }

      /* lib */
      { lib = { inherit util; }; }

      # TODO: templates
    ];
  in builtins.foldl' (a: b: a // b) { } list;
}
