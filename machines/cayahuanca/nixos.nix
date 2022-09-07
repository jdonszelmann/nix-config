inputs@{ nixos-hardware, ragenix, ... }:

{
  system = "x86_64-linux";

  modules = [
    ./hardware-configuration.nix

    # Boot/Encryption:
    {
      # boot.zfs.enableUnstable = true;

      boot.loader = {
        efi = {
          # We want to update the entries in NVRAM!
          canTouchEfiVariables = true;

          # As per `filesystems.nix`.
          efiSysMountPoint = "/boot/efi";
        };

        # We use GRUB for now but we _should_ be able to use systemd-boot,
        # I think.
        grub = {
          enable = true;
          device = "nodev";
          version = 2;
          efiSupport = true;
          enableCryptodisk = true;
        };
      };
      boot.initrd = {
        secrets = {
          # We copied these over manually as part of the installation.
          #
          # On a running system, we should be able to get these at `/etc/secrets`
          # but here we just reference them by their real persistent path so that
          # we don't need to do anything special for bootstrapping (first
          # installation).
          "/etc/secrets/boot.key" = "/persistent/etc/secrets/boot.key";
          "/etc/secrets/root.key" = "/persistent/etc/secrets/root.key";
        };

        luks.devices.boot.keyFile = "/etc/secrets/boot.key";
      };
    }


    # Filesystems:
    ./filesystems.nix
    # ZFS stuff:
    {
      # TODO: https://nixos.wiki/wiki/ZFS
      boot.kernelParams = [ "nohibernate" ];
      services.zfs.autoScrub.enable = true; # TODO

      # `/etc/secrets/root.key` is available in the initrd
      boot.zfs.requestEncryptionCredentials = true;

      # TODO: snapshots

      networking.hostId = "c9aae02d";
    }
      # TODO: zfs snapshot config


    # Common machine configuration.
    ../../mixins/nixos/laptop.nix


    # Host SSH key:
    ({ configName, ... }: {
      services.openssh.hostKeys = [
        {
          path = "/etc/secrets/${configName}";
          type = "ed25519";
        }
      ];
    })

    # Set up agenix:
    ragenix.nixosModules.age
    ({ config, configName, ... }: {
      age = {
        secretsDir = "/run/secrets";
        identityPaths = (builtins.map (p: p.path) config.services.openssh.hostKeys) ++ [
          "/run/secrets/${configName}"
          "/run/secrets/${configName}"
        ];
      };
    })

    # TODO: machine password
    # TODO: user password (+ override)

    # TODO: work config flake thing
    #  - vpn
    #  - teams
    #  - proxies
    #  - email

    # TODO: vscode
    #  - default theme
    #  - basic keybinds
    #  - github login?

    # TODO: git config (+ssh key for signing)
    #    - !!! age filter: https://seankhliao.com/blog/12020-09-24-gitattributes-age-encrypt/
    #                      https://github.com/lovesegfault/nix-config/blob/60eabb30fa2f4b435e61cd1790b8ffb7fd789422/users/bemeurer/core/git.nix#L18
    # TODO: ssh config, keys

    # TODO: ssh host key
    # TODO: add this repo to the flake registry in the machine
    # TODO: add this repo's extra caches to the user level nix config

    # TODO: systemd-boot + secure-boot

    # Display Manager, Desktop Manager, Window Manager, etc.
    {
      # the name is misleading?
      services.xserver = {
        enable = true;

        displayManager = {
          autoLogin = { user = "rahul"; enable = true; };
          gdm = {
            enable = true;
            wayland = true;
          };
          defaultSession = "gnome";
        };

        desktopManager = {
          # pantheon.enable = true; # TODO
          gnome.enable = true;
        };

        # windowManager  = ... # TODO
      };
    }

    # Users
    ../../mixins/common/users/rahul.nix
    ../../mixins/home-manager/users

    # Passsword, root:
    {
      rrbutani.users.rahul.root = true;
      rrbutani.users.rahul.ageEncryptedPasswordFile = ../../resources/secrets/r-pass.age;
    }

    # SSH:
    {
      services.openssh.enable = true;
      users.users.rahul.openssh.authorizedKeys.keys = [
        (import ../../resources/secrets/pub.nix).rahul
      ];
    }

    # User keys:
    # TODO: we'd like to have home-manager handle this but there isn't yet a
    # good home-manager (r)agenix solution.
    ({ config, configName, ... }: {
      age.secrets.r-sshKey = {
        file = ../../resources/secrets/r-gh.age;
        mode = "600";
        owner = "rahul";
      };

      home-manager.users.rahul.home.file = let
        hmConfig = config.home-manager.users.rahul;
        inherit (hmConfig.lib.file) mkOutOfStoreSymlink;
      in {
        ".ssh/gh".source = mkOutOfStoreSymlink config.age.secrets.r-sshKey.path;
        ".ssh/machine".source = mkOutOfStoreSymlink "/etc/secrets/${configName}";
      };

      # home-manager.users.rahul.home.imports = [
      #   ({ config, lib, nixosConfig, ... }: {
      #     config = {
      #       home.file = {
      #         ".ssh/gh".source = config.lib.file.mkOutOfStoreSymlink
      #           nixosConfig.age.secrets.r-sshKey.path;
      #         ".ssh/machine".source = config.lib.file.mkOutOfStoreSymlink
      #           "/etc/secrets/${configName}";
      #       };
      #     };
      #   })
      # ];

      # home-manager.users.rahul.home.file.".ssh/gh".source = "${config.age.secrets.r-sshKey.path}";
      # home-manager.users.rahul.home.file.".ssh/machine" = "/etc/secrets/${configName}";
    })

    # Set up impermanence:
    ../../modules/nixos/impermanence.nix
    {
      rrbutani.impermanence = {
        persistentStorageLocation = "/persistent";
        resetCommand = ''
          zfs rollback -r x/ephemeral/root@blank
        '';
      };

      home-manager.users.rahul.rrbutani.impermanence.extra = {
        dirs = [];
      };
    }
  ];
}
