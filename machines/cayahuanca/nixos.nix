inputs@{ nixos-hardware, ragenix, ... }:

{
  system = "x86_64-linux";

  modules = [
    ./hardware-configuration.nix

    # Boot/Encryption:
    ({ lib, ... }: {
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

        # The "problem" with systemd-boot is that it does .efi booting only and
        # does not have built in knowledge of filesystems, etc.
        #
        # This means that in order to boot with systemd, NixOS sticks its
        # initramfs and kernel in `/boot/efi`, *with* the secrets appended:
        #  - https://github.com/NixOS/nixpkgs/blob/45b92369d6fafcf9e462789e98fbc735f23b5f64/nixos/modules/system/boot/stage-1.nix#L420-L467
        #  - invoked here, on the initrd in `EFI/nixos`: https://github.com/NixOS/nixpkgs/blob/7fa06a5398cacc7357819dab136da7694de87363/nixos/modules/system/boot/loader/systemd-boot/systemd-boot-builder.py#L112-L113
        #
        # This breaks our security model; we're only okay with the secrets being
        # put in `initramfs` because we assumed it would live on `/boot`, a LUKS
        # encrypted drive, as is the case when using GRUB.
        #
        # (TODO: perhaps have the systemd-boot module warn when there are secrets
        # present? and also `top-level` or GRUB when the `/boot` location is not
        # encrypted but there are secrets..)
        #
        # If the keys aren't supplied (for LUKS), the stage1-init code in NixOS
        # *will* prompt for a password. I don't think this currently works for
        # ZFS but it doesn't seem too tricky to add some stuff that does this.
        #
        # The larger point is that `systemd-boot` isn't really compatible with
        # our scheme of having an encrypted `/boot` which then has the keys to
        # unlock `/` because `systemd-boot` does not actually use `/boot`.
        #
        # We can do away with `/boot` entirely (solving our "I don't want to
        # enter my key twice on startup" problems by only having `/`) but this
        # is undesirable because our ESP is small, difficult to resize without
        # perturbing Windows, and not where we want our kernel images to live
        # (secure boot can still guard against the kernel+efi living in the ESP
        # being tampered with but because our ESP is tiny we can't store as many
        # generations there).
        #
        # So, ideally, with `systemd-boot` our flow would be:
        #  - boot the systemd-boot .efi (secure boot signed)
        #  - have it boot a small bootstrapping thing (signed) that has file
        #    system drivers and knows how to decrypt LUKS using a password it
        #    asks us for
        #  - this bootstrapping thing should mount `/boot` and then chainload
        #    the initrd sitting there (also signed)
        #
        # This seems like a fair amount of work to retrofit into NixOS'
        # systemd-boot module and also seems like something that's unlikely to
        # ever be merged upstream.
        #
        # More to the point, the "small bootstrapping thing" described above is
        # essentially just GRUB.
        #
        # So, we should just use GRUB.
        systemd-boot.enable = lib.mkForce false;
      };

      boot.initrd = {
        # When using GRUB, the initramfs will live on `/boot` which is LUKS
        # encrypted.
        #
        # GRUB (lives on the EFI System Partition) will prompt us once to unlock
        # `/boot` and from there, it will load the initramfs.
        #
        # The initramfs will mount `/boot` a second time (as well as `/root`) as
        # part of stage1-init. We don't want to have to enter our password a
        # second time which is why we include these keys in the initramfs.
        #
        # Because the initramfs lives on encrypted storage (when using GRUB) this
        # is still secure.
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

      # `/etc/secrets/root.key` is available in the initrd
      boot.zfs.requestEncryptionCredentials = true;
    })


    # Filesystems:
    ./filesystems.nix
    # ZFS stuff:
    {
      # TODO: https://nixos.wiki/wiki/ZFS
      boot.kernelParams = [ "nohibernate" ];
      services.zfs.autoScrub.enable = true; # TODO

      # TODO: snapshots

      networking.hostId = "c9aae02d";
    }
    # TODO: zfs snapshot config

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
