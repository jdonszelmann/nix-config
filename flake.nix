{
  description = ""; # TODO
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
    agenix = {
      url = github:ryantm/agenix;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "darwin";
      inputs.home-manager.follows = "home-manager";
      inputs.systems.follows = "flake-utils/systems";
    };
    ragenix = {
      url = github:yaxitech/ragenix;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.agenix.follows = "agenix";
    };
    impermanence.url = github:nix-community/impermanence?rev=6138eb8e737bffabd4c8fc78ae015d4fd6a7e2fd; # TODO: unpin
    nix-index-database = {
      url = github:Mic92/nix-index-database/main;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = github:rrbutani/nixos-hardware/master; # TODO: switch back to upstream!
    flake-utils.url = github:numtide/flake-utils;
  };

  outputs = flakeInputs@{ self, nixpkgs, darwin, home-manager, flake-utils, ragenix, ... }: let
    inherit (nixpkgs) lib;
    dir = import ./util/list-dir.nix { inherit lib; };
    util = dir { of = ./util; mapFunc = _: v: (import v) { inherit lib; }; };
    inputs = flakeInputs // { inherit util; };

    conditionallyProvideInputs = func: inputs:
      if builtins.isFunction func && (builtins.functionArgs func) != {} then
        func inputs
      else func;
    mapFunc = _: inpPath: conditionallyProvideInputs (import inpPath) inputs;
    defaultFunc = mapFunc;

    list = [
      # Outputs tagged with a `<system>`:
      (flake-utils.lib.eachDefaultSystem (sys: let
        pkgs = nixpkgs.legacyPackages.${sys};

        # Re-export the root derivations of the configurations as checks
        # (initially this was for garnix; now it's for convenience).
        configurations = with lib; let
          tagAndExtract = { tag, ex }: mapAttrs'
            (n: v: { name = "${tag}/${n}"; value = ex v; })
            self."${tag}Configurations"
          ;
          drvs = {}
            // (tagAndExtract { tag = "nixos"; ex = d: d.config.system.build.toplevel; })
            // (tagAndExtract { tag = "darwin"; ex = d: d.system; })
            // (tagAndExtract { tag = "home"; ex = d: d.activationPackage; })
          ;
        in
          filterAttrs (n: v: v.system == sys) drvs;

        # Modules in `util`s can have a `checks: { pkgs }: { /* drv set */ }`
        # attribute:
        utilChecks = with lib; lib.pipe util [
          (filterAttrsRecursive (n: v: n == "checks" && builtins.isFunction v))
          (mapAttrsRecursive (_: v: recurseIntoAttrs (v { inherit pkgs; })))
          (recurseIntoAttrs)
        ];
      in {
        # TODO: do we have other checks?
        # package passthru tests?
        # nixos module tests?
        # util tests?
        checks = utilChecks;

        # TODO: packages: ./packages
        # TODO: apps: getExe + ./packages?
        packages.ragenix = ragenix.packages.${sys}.default; # Just so garnix will build this

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
        includeFilesWithExtension = "home.nix"; # i.e. `arm.home.nix`
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
