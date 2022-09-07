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


    # Users
    ../../mixins/common/users/rahul.nix
    ../../mixins/home-manager/users

  ];
}
