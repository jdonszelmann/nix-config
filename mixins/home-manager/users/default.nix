{ config, lib, pkgs, options, home-manager, util, specialArgs, system, ... }: let
  inherit (lib.systems.elaborate system) isDarwin;
in {
  # Add the home-manager module and make the flake inputs accessible to
  # home-manager modules:
  imports = [
    home-manager.${if isDarwin then "darwinModules" else "nixosModules"}.home-manager
    {
      home-manager = {
        extraSpecialArgs = specialArgs // {
          ${if isDarwin then "nixDarwinConfig" else "nixOsConfig"} = config;
        };

        # This (nixos/nix-darwin) module is always meant to be used in the
        # context of system configuration; for such scenarios we always want to
        # use `pkgs` (the "system" packages) in home-manager and we want to
        # allow the installation of user packages:
        #
        # nixos:
        #  - https://nix-community.github.io/home-manager/nixos-options.html#nixos-opt-home-manager.useGlobalPkgs
        #  - https://nix-community.github.io/home-manager/nixos-options.html#nixos-opt-home-manager.useUserPackages
        #
        # nix-darwin:
        #  - https://nix-community.github.io/home-manager/nix-darwin-options.html#nix-darwin-opt-home-manager.useGlobalPkgs
        #  - https://nix-community.github.io/home-manager/nix-darwin-options.html#nix-darwin-opt-home-manager.useUserPackages
        useUserPackages = true;
        useGlobalPkgs = true;

        verbose = true;
      };
    }
  ];

  config = let
    cfg = config.rrbutani.users;
    dir = util.list-dir { inherit lib; };

    hmEnabledUsers = lib.filterAttrs (_: v: v.useHmConfig or false) cfg;

    hmUserConfigs = let
      res = dir { of = ./.; mapFunc = _: import; };
    in
      /* leave out `default.nix` (this file) */
      lib.filterAttrs (n: _: n != "default") res;
    matchedHmUserConfigs = lib.mapAttrs (
      n: _: hmUserConfigs.${n} # we want to throw if we can't find a matching config
    ) hmEnabledUsers;
  in {
    warnings =
      (lib.optional (matchedHmUserConfigs == {}) ("\n\n" + ''
        `home-manager/users` was imported but no users were specified!

        These are the users we have home-manager configs for:
        ${builtins.toString (lib.mapAttrsToList (n: _: "  - `${n}`\n") hmUserConfigs)}
      ''));
    assertions = let
      isEnabledUser = if isDarwin then
        /* for `nix-darwin`, filter on `isHidden` */
        u: !u.isHidden
      else
        /* for `nixos`, filter on `isNormalUser` */
        u: u.isNormalUser
      ;
    in
      lib.mapAttrsToList (n: _: {
        assertion = isEnabledUser config.users.users.${n};
        message = "(adding a home-manager config for `${n}`) " + (
          if isDarwin then ''
            `${n}` shouldn't be a hidden user! (i.e. `isHidden = false;`)
          '' else ''
            `${n}` should be a normal user! (i.e. `isNormalUser = true;`)
          ''
        );
      }) matchedHmUserConfigs;

    home-manager.users = matchedHmUserConfigs;
  };
}
