{ config, options, lib, impermanence, nixOsConfig ? {}, ... }: let
  cfg = config.rrbutani.impermanence;
  nixOsImpCfg = (nixOsConfig.rrbutani or {}).impermanence or {};
in {
  imports = [ impermanence.nixosModules.home-manager.impermanence ];

  options.rrbutani.impermanence = {
    enable = lib.mkOption {
      description = lib.mdDoc ''
        Whether to enable impermanence in this home-manager configuration.

        Defaults to true if enabled in the NixOS configuration that home-manager
        is embedded in.
      '';
      type = lib.types.bool;
      default = nixOsImpCfg.enable or false;
    };

    persistentStorageLocation = lib.mkOption ({
      description = lib.mdDoc ''
        Persistent storage location. Required.
      '';
      type = lib.types.path;
      example = "/persistent/home/foo";
    } // (lib.optionalAttrs (nixOsImpCfg ? persistentStorageLocation) {
      default = nixOsImpCfg.persistentStorageLocation + "/home/" + config.home.username;
    }));

    extra = let
      impOptions = (options.home.persistence.type.getSubOptions []);
    in{
      dirs = lib.mkOption {
        description = lib.mdDoc ''
          Extra directories to persist.
        '';
        inherit (impOptions.directories) type;
        default = [];
      };
      files = lib.mkOption {
        description = lib.mdDoc ''
          Extra files to persist.
        '';
        inherit (impOptions.files) type;
        default = [];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.persistence.${cfg.persistentStorageLocation} = {
      directories = let
        dirs = [
          ".local/share/keyrings"

          # This is because the activation script falls
          # over if there isn't at least 1 bind mount (syntax error).
          #
          # TODO: fix!
          { directory = ".x"; method = "bindfs"; }

          # TODO: mark these derivations as local only so we don't
          # waste time probing caches for them..
        ] ++ cfg.extra.dirs;
      in builtins.map (
        v: if (builtins.typeOf v) != "set" then
          { directory = v; method = "symlink"; }
        else { method = "symlink"; } // v
      ) dirs; # TODO: make configurable?

      files = [
      ] ++ cfg.extra.files;
      allowOther = true;
    };
  };
}
