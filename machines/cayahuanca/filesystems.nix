{ pkgs, ... }: {
  # Boot:
  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/37943ec9-e2e3-4d22-a5b5-4cee87599d64";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."boot".device = "/dev/disk/by-uuid/699ec16a-b23b-4c56-957c-74bb79cc1596";

  fileSystems."/boot/efi" =
    # /dev/nvme0n1p1: 500MB EFI System Partition
    { device = "/dev/disk/by-uuid/B81F-C028";
      fsType = "vfat";
    };

  swapDevices =
    [
      # /dev/nvme0n1p7: 4GB Swap Partition
      { device = "/dev/disk/by-uuid/12b264ca-62c1-43b9-8ab1-5413d9475c0d"; }
    ];


  # ZFS root:
  boot.initrd.supportedFilesystems = [ "zfs" ];
  boot.supportedFilesystems = [ "zfs" ];

  # We want to use ZFS automounts and so we do this, as per:
  # https://toxicfrog.github.io/automounting-zfs-on-nixos/
  boot.zfs.devNodes = "/dev/disk/by-part-uuid/ff4cde1a-a4ce-427f-96b2-9d371582ed02";
  fileSystems."/" =
    { device = "x/ephemeral/root";
      fsType = "zfs";
    };
  fileSystems."/nix" =
    { device = "x/ephemeral/nix";
      fsType = "zfs";
    };
  # boot.postBootCommands = ''
  #   # ${pkgs.zfs}/bin/zpool import
  # '';
  # TODO: is ^ really needed? guess we'll find out

  # As per https://grahamc.com/blog/nixos-on-zfs.
  # (since we do have multiple partitions on our drive)
  boot.kernelParams = [ "elevator=none" ];

  # Misc:
  # (ZFS wants the keys to live at `/etc/secrets`; this is handled fine in the
  # initrd but here we'll need a symlink)
  environment.etc."secrets".source = "/persistent/etc/secrets";
}
