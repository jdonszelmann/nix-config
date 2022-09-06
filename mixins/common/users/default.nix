{ name, fullName ? name }:

{ lib, pkgs, config, system, ... }: let
  inherit (lib.systems.elaborate system) isDarwin;
  cfg = config.rrbutani.users.${name};
in {
  options.rrbutani.users.${name} = {
    root = lib.mkOption {
      description = lib.mkDoc ''
        Give user `${name}` sudo privileges.
      '';
      type = lib.types.bool;
      default = false;
    };

    addToNixTrustedUsers = lib.mkOption {
      description = lib.mkDoc ''
        Whether to add `${name}` to <option>nix.settings.trusted-users</option>.

        Defaults to `true` iff <option>rrbutani.users.${name}</option> is
        enabled.
      '';
      type = lib.types.bool;
      default = cfg.root;
    };
  } // (let
    hmPath = ../../home-manager/users/${name}.nix;
  in lib.optionalAttrs (lib.pathExists hmPath) {
    useHmConfig = lib.mkOption {
      description = lib.mkDoc ''
        Whether to include the `home-manager` config at ${hmPath} when the
        `home-manager` user module is included.
      '';
      type = lib.types.bool;
      default = true;
    };
  });

  config = {
    users.users.${name} = let
      nixosSpecificOptions = {
        home = "/home/${name}";
        isNormalUser = true;
        # passwordFile = ""; # TODO!

        extraGroups = lib.mkIf cfg.root [ "wheel" ];
      };

      nixDarwinSpecificOptions = {
        home = "/Users/${name}";
        isHidden = false;
      };

      extras = if isDarwin then
        nixDarwinSpecificOptions
      else
        nixosSpecificOptions;
    in {
      inherit name;
      description = "User account for ${fullName}.";
      home = "/home/${name}";
      # createHome = true; # !!! TODO: is this what we want? even on darwin?
    } // extras;

    users.groups = lib.mkIf isDarwin {
      staff.members = [ name ];
      admin.members = lib.mkIf cfg.root [ name ];
    };

    nix.settings.trusted-users = lib.mkIf cfg.addToNixTrustedUsers [ name ];
  };
}
