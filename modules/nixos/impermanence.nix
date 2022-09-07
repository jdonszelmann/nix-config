{ config, options, lib, impermanence, ... }: let
  cfg = config.rrbutani.impermanence;
in {
  imports = [ impermanence.nixosModules.impermanence ];

  options.rrbutani.impermanence = {
    enable = lib.mkOption {
      description = lib.mdDoc ''
        Whether to enable system-wide impermanence.

        Enabled by default (when this module is included).
      '';
      type = lib.types.bool;
      default = true;
    };

    resetCommand = lib.mkOption {
      description = lib.mdDoc ''
        Command to reset `/`, if required.
      '';
      type = lib.types.str;
      default = "";
      example = "zfs rollback -r x/ephemeral/root@blank";
    };

    persistentStorageLocation = lib.mkOption {
      description = lib.mdDoc ''
        Persistent storage location. Required.
      '';
      type = lib.types.path;
      example = "/persistent";
    };

    extra = let
      impOptions = (options.environment.persistence.type.getSubOptions []);
    in {
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
    environment.persistence.${cfg.persistentStorageLocation} = {
      # Sets mount option `x-gvfs-hide` on the resulting bind mounts.
      hideMounts = true;

      directories = [
        "/etc/NetworkManager/system-connections" # TODO: manage this in nix?
        "/var/lib/bluetooth"                     # TODO: manage this in nix?
      ] ++ cfg.extra.dirs;

      files = [
        "/etc/machine-id"
      ] ++ cfg.extra.files;
    };

    # As per the impermanence README, this is required for `allowOther = true`.
    programs.fuse.userAllowOther = true;

    boot.initrd.postDeviceCommands = lib.mkAfter cfg.resetCommand;
  };
}
