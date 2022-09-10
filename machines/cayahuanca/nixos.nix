inputs@{ nixos-hardware, ragenix, ... }:

{
  system = "x86_64-linux";

  modules = [
    ./hardware-configuration.nix

    # Boot/Encryption:
    ./boot-and-encryption.nix

    # Filesystems:
    ./filesystems.nix
    # ZFS stuff:
    {
      # https://nixos.wiki/wiki/ZFS

      # Hibernate doesn't interact with ZFS well so disable it:
      boot.kernelParams = [ "nohibernate" ];

      services.zfs.autoScrub.enable = true;

      # We're on an SSD, run trim periodically:
      services.zfs.trim.enable = true;

      # Snapshot config for ZFS.
      #
      # ZFS has built in auto snapshotting support which stores the snapshotting
      # metadata with the dataset config:
      #  - https://docs.oracle.com/cd/E19120-01/open.solaris/817-2271/gbcxl/index.html
      #  - https://serverfault.com/a/1059405
      #
      # And NixOS supports this with the `services.zfs.autoSnapshot.enable` key:
      #  - https://search.nixos.org/options?channel=22.05&show=services.zfs.autoSnapshot.enable&from=0&size=50&sort=relevance&type=packages&query=services.zfs.autoSnapshot.enable
      #
      # But, this is less configurable than sanoid so we just use sanoid for
      # now.
      #
      # See: https://github.com/jimsalterjrs/sanoid/blob/master/sanoid.defaults.conf
      # And: https://search.nixos.org/options?channel=22.05&from=0&size=50&sort=relevance&type=options&query=sanoid
      #
      # To get a sense of the options.
      services.sanoid = {
        enable = true;
        datasets = {
          # Don't snapshot `x/ephemeral/*`.
          #  - `x/ephemeral/nix` is completely reproducible
          #  - `x/ephemeral/root` is wiped away on boot anyways; all the
          #    stuff worth keeping is actually just hardlinks and symlinks to
          #    `x/persistent`
          #    + taking snapshots of `root` would actually break the rollback
          #      on boot

          # *Do* snapshot `x/persistent/*`.
          "x/persistent" = {
            recursive = true;
            yearly = 0;
            monthly = 2;
            daily = 7;
            hourly = 0;
            autosnap = true;
            autoprune = true;
          };
          "x/persistent/home" = {
            recursive = true;
            monthly = 4;
            daily = 15;
            hourly = 2;
          };
          "x/persistent/home/rahul/dev" = {
            recursive = true;

            # Backup `dev` more frequently but don't keep these backups around
            # for very long.
            monthly = 0;
            daily = 7;
            hourly = 48;
            frequently = 8;
            frequent_period = 15;
          };
        };
      };

      # TODO: syncoid for backups

      # Required for ZFS
      networking.hostId = "c9aae02d";
    }

    # Common machine configuration.
    ../../mixins/nixos/laptop.nix

    # Fingerprint Auth:
    ../../mixins/nixos/fprint.nix

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
        identityPaths = [
          # For bootstrapping.
          #
          # This needs to go first because of this bug:
          # https://github.com/ryantm/agenix/issues/116
          # https://github.com/str4d/rage/issues/294
          "/persistent/etc/secrets/${configName}"
          "/etc/secrets/${configName}"

          # config.age.secrets.machine-key.path # See above! doesn't exist while bootstrapping so we need to disable it
        ] ++ (builtins.map (p: p.path) config.services.openssh.hostKeys);

        secrets.machine-key.file = ../../resources/secrets/cayahuanca.age;
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

    # TODO: zram swap

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
