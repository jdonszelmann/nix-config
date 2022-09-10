{pkgs, ...}: {
  # Boot:
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/37943ec9-e2e3-4d22-a5b5-4cee87599d64";
    fsType = "ext4";
  };

  boot.initrd.luks.devices."boot".device =
    "/dev/disk/by-uuid/699ec16a-b23b-4c56-957c-74bb79cc1596";

  # /dev/nvme0n1p1: 500MB EFI System Partition
  fileSystems."/boot/efi" =
    {
      device = "/dev/disk/by-uuid/B81F-C028";
      fsType = "vfat";
    };

  swapDevices = [
    # /dev/nvme0n1p7: 4GB Swap Partition
    {device = "/dev/disk/by-uuid/12b264ca-62c1-43b9-8ab1-5413d9475c0d";}
  ];

  # ZFS root:
  boot.initrd.supportedFilesystems = ["zfs"];
  boot.supportedFilesystems = ["zfs"];

  # We want to use ZFS automounts.
  #
  # Some of the early things in stage 1 require `/` and `/nix` to be present so
  # we let NixOS know about these mount explicitly.
  #
  # Normally NixOS automatically mounts all ZFS datasets, just later in the boot
  # process.
  #
  # We have some steps in stage2 (age secret decryption, impermanence, etc.)
  # that require some of our other datasets to be mounted so: we explicitly
  # mount everything at the end of stage 1 with a `postMountCommands` snippet.
  #
  # This has some relevant stuff:
  # https://toxicfrog.github.io/automounting-zfs-on-nixos/
  fileSystems."/" = {
    device = "x/ephemeral/root";
    fsType = "zfs";
  };
  fileSystems."/nix" = {
    device = "x/ephemeral/nix";
    fsType = "zfs";
  };
  # fileSystems."/persistent" = {
  #   device = "x/persistent";
  #   fsType = "zfs";
  #   neededForBoot = true;
  # };
  boot.initrd.postMountCommands = ''
    zfs mount -a
  '';

  # As per https://grahamc.com/blog/nixos-on-zfs.
  # (since we do have multiple partitions on our drive)
  #
  # TODO: this is deprecated; update this! (sys params?)
  boot.kernelParams = ["elevator=none"];
}
