https://en.wikipedia.org/wiki/HD_52265_b

<!-- "the rock looking at the stars" -->
<!-- commit tag: caya -->

TODOs:
  - `psmouse.synaptics_intertouch=0` for T15: https://superuser.com/questions/1649041/thinkpad-t15-clickpad-button-not-working-in-linux
    + add to nixos hardware repo!
  - synaptics inc. prometheus fingerprint reader 06cb 00bd; seems supported: https://fprint.freedesktop.org/supported-devices.html
  - https://davejansen.com/add-custom-resolution-and-refresh-rate-when-using-wayland-gnome/
  - zram swap: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/zram.nix

## Drives

256GB SK Hynix BC511 HFM256GDJTNI-82A0A (as per `lsblk -io KNAME,SIZE,MODEL`)
  - has a 512B sector size (as per `sudo blockdev --getpbsz --getss /dev/nvme0n1`)

## Partitions

partitions:
  - EFI system partition (500MB)
  - windows ?? (128MB)
  - Windows Main (98.76GB)
  - Boot partition (5GB)
    + (systemd-boot and GRUB cannot boot from encrypted ZFS)
    + LUKS encrypted
  - ZFS partition (rest, ~127.72GB or so)
  - Swap (4GB)
  - Windows Recovery (2.38GB)

TODO: diagram

## Setup

(mostly just follows the [instructions for `pirx`](../pirx/README.md))

### Filesystems

1) Set up `/dev/nvme0n1`:

  ```bash
  $ sudo sfdisk --dump /dev/nvme0n1
  label: gpt
  label-id: 20C9EE9C-0BB5-487C-ADE6-629D6C61B63F
  device: /dev/nvme0n1
  unit: sectors
  first-lba: 34
  last-lba: 500118158
  sector-size: 512

  /dev/nvme0n1p1 : start=        2048, size=     1021952, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=432958C4-4CEC-4466-AC19-E9034321C6D2, name="EFI system partition"
  /dev/nvme0n1p2 : start=     1024000, size=      262144, type=E3C9E316-0B5C-4DB8-817D-F92DF00215AE, uuid=228F10F1-A6A1-418B-9A39-76374A195E33, name="Microsoft reserved partition"
  /dev/nvme0n1p3 : start=     1286144, size=   207110144, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, uuid=E0486869-EDD2-4A39-9B18-66EA2DE1ADEE, name="Basic data partition"
  /dev/nvme0n1p4 : start=   495116288, size=     5001216, type=DE94BBA4-06D1-4D40-A16A-BFD50179D6AC, uuid=5CAAD645-D0BD-41D9-B886-CEE1A1AA1CD5, name="Basic data partition"
  /dev/nvme0n1p5 : start=   208396288, size=    10485760, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=C99B2105-9587-49F7-AB9F-DCB58E87F325, name="boot"
  /dev/nvme0n1p6 : start=   218882048, size=   267845632, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=FF4CDE1A-A4CE-427F-96B2-9D371582ED02, name="root"
  /dev/nvme0n1p7 : start=   486727680, size=     8388608, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, uuid=5E8390BC-59AE-48B8-AED9-5992B648BBC7, name="swap"
  ```

2) Set up encryption keys.

  `/boot` will be LUKS1 encrypted, `/root` will use ZFS' built-in encryption.

  We'll have two keys:
    - one for LUKS
    - one for ZFS

  ```bash
  $ dd if=/dev/urandom of=./boot.key bs=512 count=1
  $ dd if=/dev/urandom of=./root.key bs=512 count=1
  ```

3) Make partitions.

  Assuming the ESP and Windows partitions already exist.

  - Boot:
    + Opaque "Linux" partition type:
      * `sudo fdisk /dev/nvme0n1`
        - `t`
        - `5` to select the `boot` partition (`/dev/nvme0n1p5`)
        - `linux`
        - `p` to verify
        - `w` to write
    + Set up LUKS:
      ```bash
      $ args =(
        --type=luks1

        --cipher=aes-xts-plain64 # As per `cryptsetup benchmark`
        --key-size=256

        --hash=sha256
        --use-urandom
        --iter-time=100
        --verify-passphrase
        --sector-size=512
      )

      # Enter the password you'll need to boot:
      $ sudo cryptsetup luksFormat "${args[@]}" /dev/nvme0n1p5

      # Add the keyfile:
      $ sudo cryptsetup luksAddKey /dev/nvme0n1p5 ./boot.key
      ```
    + Create the filesystem:
      ```bash
      # Mount/unlock:
      $ sudo cryptsetup luksOpen /dev/nvme0n1p5 boot-partition -d ./boot.key

      # Make a filesystem (ext4):
      $ sudo mkfs.ext4 -L boot /dev/mapper/boot-partition
      ```
  - Root:
    + Partition type:
      * `sudo fdisk /dev/nvme0n1`
        - `t`
        - `6`
        - `66` for the Solaris root partition type (ZFS)
        - `w`
    + Set up ZFS:
      - zstd benchmarks:
        ```bash
        $ for i in {0..19}; do zstd -b$i; done
        ```
        yields:
        ```
         0#Synthetic 50%     :  10000000 ->   3230847 (x3.095),  239.6 MB/s, 1843.1 MB/s
         1#Synthetic 50%     :  10000000 ->   3154223 (x3.170),  390.8 MB/s, 1776.7 MB/s
         2#Synthetic 50%     :  10000000 ->   3129112 (x3.196),  284.1 MB/s, 1695.1 MB/s
         3#Synthetic 50%     :  10000000 ->   3230847 (x3.095),  157.8 MB/s, 1216.0 MB/s
         4#Synthetic 50%     :  10000000 ->   3345685 (x2.989),  137.1 MB/s, 1098.4 MB/s
         5#Synthetic 50%     :  10000000 ->   3296620 (x3.033),   87.9 MB/s, 1048.9 MB/s
         6#Synthetic 50%     :  10000000 ->   3284857 (x3.044),   74.8 MB/s, 1115.4 MB/s
         7#Synthetic 50%     :  10000000 ->   3328432 (x3.004),   62.4 MB/s, 1027.0 MB/s
         8#Synthetic 50%     :  10000000 ->   3319322 (x3.013),   56.5 MB/s, 1037.0 MB/s
         9#Synthetic 50%     :  10000000 ->   3357642 (x2.978),   45.4 MB/s,  925.9 MB/s
        10#Synthetic 50%     :  10000000 ->   3363183 (x2.973),   35.0 MB/s,  898.0 MB/s
        11#Synthetic 50%     :  10000000 ->   3363177 (x2.973),   26.3 MB/s,  892.2 MB/s
        12#Synthetic 50%     :  10000000 ->   3362876 (x2.974),   25.0 MB/s,  900.7 MB/s
        13#Synthetic 50%     :  10000000 ->   3354692 (x2.981),   9.55 MB/s,  966.0 MB/s
        14#Synthetic 50%     :  10000000 ->   3354678 (x2.981),   10.5 MB/s,  964.9 MB/s
        15#Synthetic 50%     :  10000000 ->   3353801 (x2.982),   8.54 MB/s,  943.7 MB/s
        16#Synthetic 50%     :  10000000 ->   3080659 (x3.246),   6.53 MB/s, 1737.8 MB/s
        17#Synthetic 50%     :  10000000 ->   3137591 (x3.187),   2.98 MB/s, 1382.3 MB/s
        18#Synthetic 50%     :  10000000 ->   3144966 (x3.180),   2.74 MB/s, 1336.8 MB/s
        19#Synthetic 50%     :  10000000 ->   3145226 (x3.179),   2.27 MB/s, 1332.8 MB/s
        ```

      ```bash
      # Create the zpool:
      $ args=(
        # No `zpool` level mountpoint:
        -m none

        # Our disk sector size is 512B which is an ashift of 9, the minimum;
        # this means there's no "risk" of choosing a too small ashift value.
        #
        # So, let ZFS pick:
        -o ashift=0

        # We're on an SSD but according to `man zpoolprops`, `autotrim` can be
        # hard on underlying storage devices.
        #
        # So, instead of enabling `autotrim`, we just use the NixOS trim option
        # which runs `zfs trim` periodicially:
        #   - https://nixos.wiki/wiki/ZFS#Auto_ZFS_trimming
        #   - https://github.com/NixOS/nixpkgs/blob/67e45078141102f45eff1589a831aeaa3182b41e/nixos/modules/tasks/filesystems/zfs.nix#L790-L804
        -o autotrim=off

        # We don't actually need to stay GRUB2 compatible since `/boot` does
        # not live on ZFS!
        # -o compatibility=grub2

        # Just an unencrypted comment.
        -o comment='Root zpool for `cayahuanca`'

        -o listsnaps=on

        # Of SHA256, SHA512 (+30%), edonr(+300+%), skein(+80%), `edonr` is the fastest.
        #
        # So, we want to be able to use this as the checksum and dedupe algorithms (TODO).
        -o feature@edonr=enabled

        # Better compression for highly-compressible blocks.
        #
        # (nvm, not supported on Linux)
        # -o feature@embdded_data=enabled

        # Enable encryption:
        -o feature@encryption=enabled

        # Enable zstd compression:
        -o feature@zstd_compress=enabled

        # Enable lz4 compression too (though we do not intend to use it):
        -o feature@lz4_compress=enabled

        ### File system properties:

        # Disable `atime` for better performance:
        -O atime=off

        # It's not clear if `edonr` is _actually_ faster than `fletcher4` (the
        # default algorithm used for checksums).
        #
        # I have not been able to find good benchmarks comparing the two but
        # there is this thread (Jan 2021) that alleges that `fletcher4` is
        # better optimized for Intel CPUs: https://jira.whamcloud.com/browse/LU-14320
        #
        # Fletcher4 benchmarks are accessible via: `/proc/spl/kstat/zfs/fletcher4_bench`
        #
        # However, since we're enabling `dedup` anyways, this isn't relevant;
        # `dedup` will change the `checksum` algorithm to match and `fletcher4`
        # is not available as a `dedup` algorithm.
        -O checksum=on

        # The benchmarking above suggests zstd-2 is a probably a good
        # speed/compression ratio tradeoff:
        -O compression=zstd-2

        # Enable dedupe using `edonr`.
        #
        # `edonr` currently requires `verify` (hash matches are verified, byte
        # by byte)out of an abundance of caution.
        -O dedup=edonr,verify

        # Enable encryption.
        #
        # aes gcm cipher suites are generally considered faster than aes ccm:
        # https://crypto.stackexchange.com/questions/6842/how-to-choose-between-aes-ccm-and-aes-gcm-for-storage-volume-encryption
        #
        # I did not benchmark the different block sizes; the ZFS default is
        # `aes-256-gcm` which is what I'm using here:
        -O encryption=aes-256-gcm

        # We select the passphrase keyformat instead of raw or hex because we
        # wanted to use a 512B key (the other formats are capped at 32B):
        -O keyformat=passphrase

        # We'll store the key at `/etc/secrets/root.key`.
        #
        # We want to tell ZFS this so that we don't need to do more than run
        # `load-key` on startup.
        #
        # (this is supported by the nixos zfs module:
        # https://github.com/NixOS/nixpkgs/blob/67e45078141102f45eff1589a831aeaa3182b41e/nixos/modules/tasks/filesystems/zfs.nix#L290-L301
        # )
        #
        # (as an aside, it's kind of wild that you can specify the keylocation
        # to be a _URL_)
        -O keylocation=file:///etc/secrets/root.key

        # According to `cryptsetup benchmark`, we can do ~2.5M iterations of
        # PBKDF2-SHA256 in a second on this machine.
        #
        # This means the default setting of 350000 iterations will take 0.14
        # seconds which seems fine.
        #
        # Brute forcing a 512 byte passphrase seems impractical regardless of
        # the number of pbkdf2 iterations.
        -O pbkdf2iters=350000

        # Have a snapshot limit:
        -O snapshot_limit=200

        # Allow some redundant metadata writes to be elided:
        -O redundant_metadata=most

        # Show the `.zfs` snapshots directory on file systems:
        -O snapdir=visible

        # Store extended attrs as system attributes:
        -O xattr=sa
      )

      # Create a pool named `x` on `/dev/nvme0n1p6` with the options above:
      sudo zpool create "${args[@]}" x /dev/nvme0n1p6

      # Create the top-level datasets (but don't mount: -u):
      #
      # A grahamc inspired arrangement, see: https://grahamc.com/blog/nixos-on-zfs
      ephem_ds_args=(
        # Just a container, don't mount.
        -o mountpoint=none

        # Disable snapshots.
        -o snapshot_limit=0

        x/ephemeral
      )
      sudo zfs create -v -u "${ephem_ds_args[@]}"

      sys_ds_args=(
        # Just a container, don't mount.
        -o mountpoint=none

        # Periodic snapshots, short retention.
        # TODO

        # So that things like journalctl work, enable posix acls:
        -o acltype=posixacl

        x/system
      )
      sudo zfs create -v -u "${sys_ds_args[@]}"

      user_ds_args=(
        # Just a container, don't mount.
        -o mountpoint=none

        # Regular snapshots, long retention.
        # TODO

        x/user
      )
      sudo zfs create -v -u "${user_ds_args[@]}"

      # Create the datasets to actually mount:
      # `/nix`:
      sudo zfs create -v -u -o mountpoint=/nix x/ephemeral/nix
        # disable dedupe:
        sudo zfs set dedup=off x/ephemeral/nix
        # use fletcher4? TODO, not sure

      # `/root`:
      sudo zfs create -v -u -o mountpoint=/    x/system/root

      # `/`:
      sudo zfs create -v -u -o mountpoint=/home x/user/home
      sudo zfs create -v -u                     x/user/home/rahul
      sudo zfs create -v -u                     x/user/home/rahul/dev
      # TODO: hide the .zfs dir on sub-datasets?

      # TODO:
      sudo zpool export x

      sudo mkdir -p /mnt
      sudo zpool import x -R /mnt
      sudo zfs load-key -a
      sudo zfs mount -a
      ```
  - Swap:
    + Partition type:
      * `sudo fdisk /dev/nvme0n1`
        - `t`
        - `7` to select `/dev/nvme0n1p7`
        - `swap`
        - `w`
    + Finally: `sudo mkswap -L swap /dev/nvme0n1p7`
  - Ultimately you should have:
    ```bash
    $ sudo fdisk -l /dev/nvme0n1
    TODO
    $ sudo cryptsetup luksDump /dev/nvme0n1p5
    TODO
    $ sudo zpool list -v
    TODO
    ```

4) Finally, mount the filesystems and copy over the keys:


###

re-enable secure boot


ZFS todo:
  - elevator none in the kernel for scheduling since we're not the only partition on the disk
