{ config, lib, pkgs, home-manager, util, specialArgs, ... }: let
  # inherit (pkgs.stdenv.hostPlatform) isDarwin;
  isDarwin = false;
in {
  # Add the home-manager module and make the flake inputs accessible to
  # home-manager modules:
  imports = [
    home-manager.${if isDarwin then "darwinModules" else "nixosModules"}.home-manager
    {
      home-manager = {
        extraSpecialArgs = specialArgs;

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
      };
    }
  ];

  config = let
    dir = util.list-dir { inherit lib; };

    isEnabledUser = if isDarwin then
      /* for `nix-darwin`, filter on `isHidden` */
      u: !u.isHidden
    else
      /* for `nixos`, filter on `isNormalUser` */
      u: u.isNormalUser
    ;

    hmUserConfigs = let
      res = dir { of = ./.; mapFunc = _: import; };
    in
      /* leave out `default.nix` (this file) */
      lib.filterAttrs (n: _: n != "default") res;
    matchedHmUserConfigs = lib.filterAttrs (
      n: _: (
        # lib.hasAttr n config.users.users &&
        # isEnabledUser config.users.users.${n}
        false
      )
    ) hmUserConfigs;
  in {
    warnings =
      (lib.optional (matchedHmUserConfigs == {}) ("\n\n" + ''
        `home-manager/users` was imported but no matching home-manager configs
        were found for the currently enabled users!

        These are the users we have home-manager configs for:
        ${builtins.toString (lib.mapAttrsToList (n: _: "  - `${n}`\n") hmUserConfigs)}
      ''));

#  ++
#      (lib.optional (enabledUsers == {}) ("\n\n" + ''
#         No enabled users were detected!

#         Perhaps you included the `home-manager/users` mixin _before_ defining
#         users in your ${if isDarwin then "nix-darwin" else "nixos"} configuration?
#       ''));

    home-manager.users = matchedHmUserConfigs;
  };
}
