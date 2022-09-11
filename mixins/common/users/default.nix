{ name, fullName ? name }:

{ lib, pkgs, config, system, ... }: let
  inherit (lib.systems.elaborate system) isDarwin;
  cfg = config.rrbutani.users.${name};
in {
  options.rrbutani.users.${name} = {
    root = lib.mkOption {
      description = lib.mdDoc ''
        Give user `${name}` sudo privileges.
      '';
      type = lib.types.bool;
      default = false;
    };

    addToNixTrustedUsers = lib.mkOption {
      description = lib.mdDoc ''
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
      description = lib.mdDoc ''
        Whether to include the `home-manager` config at ${hmPath} when the
        `home-manager` user module is included.
      '';
      type = lib.types.bool;
      default = true;
    };
  }) // (lib.optionalAttrs (!isDarwin) {
    ageEncryptedPasswordFile = lib.mkOption {
      description = lib.mdDoc ''
        Optional path to an age encrypted, encrypted password file.

        These can be generated with:
        ```bash
        mkpasswd --stdin --method=sha-256
        ```

        And then encrypted with (r)age. For example:
        ```bash
        mkpasswd --stdin --method=sha-256 | ragenix --edit password.age --editor tee
        ```

        Note that if this option is set, this module assumes that the `age`
        NixOS module has been imported and configured: we will set age options
        without importing it first which will cause errors if you have not
        already imported `age`.
      '';
      type = lib.types.path;
    };
  });

  config = {
    age.secrets.${"${name}.pass"} = {
      file = lib.mkIf (cfg ? ageEncryptedPasswordFile)
        cfg.ageEncryptedPasswordFile;
    };

    users.users.${name} = let
      nixosSpecificOptions = {
        home = "/home/${name}";
        isNormalUser = true;

        passwordFile = lib.mkIf (cfg ? ageEncryptedPasswordFile)
          config.age.secrets.${"${name}.pass"}.path;

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
      description = fullName;
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
