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
  # But, this is less configurable than sanoid so we just use sanoid for now.
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
      #  - `x/ephemeral/root` is wiped away on boot anyways; all the stuff worth
      #    keeping is actually just hardlinks and symlinks to `x/persistent`
      #    + taking snapshots of `root` would actually break the rollback on
      #      boot

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

        # Backup `dev` more frequently but don't keep these backups around for
        # very long.
        monthly = 0;
        daily = 14;
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
