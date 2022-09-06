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

  TODO: perhaps look into _describing_ these partitions with [`disko`](https://github.com/nix-community/disko)

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
      $ args=(
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

      # Unmount:
      $ sudo cryptsetup luksClose /dev/mapper/boot-partition
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
    ```
    <details>

    ```
    Disk /dev/nvme0n1: 238.47 GiB, 256060514304 bytes, 500118192 sectors
    Disk model: SK hynix BC511 HFM256GDJTNI-82A0A
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    Disklabel type: gpt
    Disk identifier: 20C9EE9C-0BB5-487C-ADE6-629D6C61B63F
    First LBA: 34
    Last LBA: 500118158
    Alternative LBA: 500118191
    Partition entries LBA: 2
    Allocated partition entries: 128

    Device             Start       End   Sectors Type-UUID                            UUID                                 Name                         Attrs
    /dev/nvme0n1p1      2048   1023999   1021952 C12A7328-F81F-11D2-BA4B-00A0C93EC93B 432958C4-4CEC-4466-AC19-E9034321C6D2 EFI system partition
    /dev/nvme0n1p2   1024000   1286143    262144 E3C9E316-0B5C-4DB8-817D-F92DF00215AE 228F10F1-A6A1-418B-9A39-76374A195E33 Microsoft reserved partition
    /dev/nvme0n1p3   1286144 208396287 207110144 EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 E0486869-EDD2-4A39-9B18-66EA2DE1ADEE Basic data partition
    /dev/nvme0n1p4 495116288 500117503   5001216 DE94BBA4-06D1-4D40-A16A-BFD50179D6AC 5CAAD645-D0BD-41D9-B886-CEE1A1AA1CD5 Basic data partition
    /dev/nvme0n1p5 208396288 218882047  10485760 0FC63DAF-8483-4772-8E79-3D69D8477DE4 C99B2105-9587-49F7-AB9F-DCB58E87F325 boot
    /dev/nvme0n1p6 218882048 486727679 267845632 6A85CF4D-1DD2-11B2-99A6-080020736631 FF4CDE1A-A4CE-427F-96B2-9D371582ED02 root
    /dev/nvme0n1p7 486727680 495116287   8388608 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F 5E8390BC-59AE-48B8-AED9-5992B648BBC7 swap

    Partition table entries are not in disk order.
    ```
    </details>


    ```bash
    $ sudo cryptsetup luksDump /dev/nvme0n1p5
    ```
    <details>

    ```
    LUKS header information for /dev/nvme0n1p5

    Version:       	1
    Cipher name:   	aes
    Cipher mode:   	xts-plain64
    Hash spec:     	sha256
    Payload offset:	4096
    MK bits:       	256
    MK digest:     	33 c8 76 a2 68 85 30 ac f7 fd fd b1 02 ef 99 04 36 84 a0 91
    MK salt:       	be 55 87 c8 fa 57 d3 38 d0 f2 ca f7 b0 5b 50 6d
                    62 9c aa 96 60 84 ce 71 62 f1 20 35 a8 20 64 14
    MK iterations: 	229547
    UUID:          	699ec16a-b23b-4c56-957c-74bb79cc1596

    Key Slot 0: ENABLED
      Iterations:         	172179
      Salt:               	b5 18 91 23 12 51 15 9b df 87 43 ee 18 01 05 46
                              91 9b 32 3e b6 d5 e6 25 1e 33 60 55 ee 42 0c c6
      Key material offset:	8
      AF stripes:            	4000
    Key Slot 1: ENABLED
      Iterations:         	2264742
      Salt:               	ef 8c 16 04 db c4 b8 06 19 8a 45 fa 7f a4 43 2a
                              2c 0b 2c c4 af b0 5e 52 c1 e7 94 05 73 d1 3e 25
      Key material offset:	264
      AF stripes:            	4000
    Key Slot 2: DISABLED
    Key Slot 3: DISABLED
    Key Slot 4: DISABLED
    Key Slot 5: DISABLED
    Key Slot 6: DISABLED
    Key Slot 7: DISABLED
    ```
    </details>

    ```bash
    $ sudo zpool import x && \
      sudo zfs load-key -L file://$(realpath ./root.key) x && \
      sudo zpool list -v && \
      sudo zfs list && \
      sudo zfs get all x x/{ephemeral{,/nix},system,user} && \
      sudo zpool export x
    ```
    <details>

    ```
    NAME          SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
    x             127G  1.45M   127G        -         -     0%     0%  1.00x    ONLINE  -
      nvme0n1p6   127G  1.45M   127G        -         -     0%  0.00%      -    ONLINE
    NAME                    USED  AVAIL     REFER  MOUNTPOINT
    x                      1.39M   123G       98K  none
    x/ephemeral             196K   123G       98K  none
    x/ephemeral/nix          98K   123G       98K  /nix
    x/system                198K   123G       98K  none
    x/system/root           100K   123G      100K  /
    x/user                  394K   123G       98K  none
    x/user/home             296K   123G       99K  /home
    x/user/home/rahul       197K   123G       99K  /home/rahul
    x/user/home/rahul/dev    98K   123G       98K  /home/rahul/dev
    NAME             PROPERTY              VALUE                         SOURCE
    x                type                  filesystem                    -
    x                creation              Sat Sep  3 19:39 2022         -
    x                used                  1.39M                         -
    x                available             123G                          -
    x                referenced            98K                           -
    x                compressratio         1.00x                         -
    x                mounted               no                            -
    x                quota                 none                          default
    x                reservation           none                          default
    x                recordsize            128K                          default
    x                mountpoint            none                          local
    x                sharenfs              off                           default
    x                checksum              on                            local
    x                compression           zstd-2                        local
    x                atime                 off                           local
    x                devices               on                            default
    x                exec                  on                            default
    x                setuid                on                            default
    x                readonly              off                           default
    x                zoned                 off                           default
    x                snapdir               visible                       local
    x                aclmode               discard                       default
    x                aclinherit            restricted                    default
    x                createtxg             1                             -
    x                canmount              on                            default
    x                xattr                 sa                            local
    x                copies                1                             default
    x                version               5                             -
    x                utf8only              off                           -
    x                normalization         none                          -
    x                casesensitivity       sensitive                     -
    x                vscan                 off                           default
    x                nbmand                off                           default
    x                sharesmb              off                           default
    x                refquota              none                          default
    x                refreservation        none                          default
    x                guid                  15623246681462713644          -
    x                primarycache          all                           default
    x                secondarycache        all                           default
    x                usedbysnapshots       0B                            -
    x                usedbydataset         98K                           -
    x                usedbychildren        1.29M                         -
    x                usedbyrefreservation  0B                            -
    x                logbias               latency                       default
    x                objsetid              54                            -
    x                dedup                 edonr,verify                  local
    x                mlslabel              none                          default
    x                sync                  standard                      default
    x                dnodesize             legacy                        default
    x                refcompressratio      1.00x                         -
    x                written               98K                           -
    x                logicalused           622K                          -
    x                logicalreferenced     49K                           -
    x                volmode               default                       default
    x                filesystem_limit      none                          default
    x                snapshot_limit        200                           local
    x                filesystem_count      8                             local
    x                snapshot_count        0                             local
    x                snapdev               hidden                        default
    x                acltype               off                           default
    x                context               none                          default
    x                fscontext             none                          default
    x                defcontext            none                          default
    x                rootcontext           none                          default
    x                relatime              off                           default
    x                redundant_metadata    most                          local
    x                overlay               on                            default
    x                encryption            aes-256-gcm                   -
    x                keylocation           file:///etc/secrets/root.key  local
    x                keyformat             passphrase                    -
    x                pbkdf2iters           350000                        -
    x                encryptionroot        x                             -
    x                keystatus             available                     -
    x                special_small_blocks  0                             default
    x/ephemeral      type                  filesystem                    -
    x/ephemeral      creation              Sat Sep  3 19:39 2022         -
    x/ephemeral      used                  196K                          -
    x/ephemeral      available             123G                          -
    x/ephemeral      referenced            98K                           -
    x/ephemeral      compressratio         1.00x                         -
    x/ephemeral      mounted               no                            -
    x/ephemeral      quota                 none                          default
    x/ephemeral      reservation           none                          default
    x/ephemeral      recordsize            128K                          default
    x/ephemeral      mountpoint            none                          local
    x/ephemeral      sharenfs              off                           default
    x/ephemeral      checksum              on                            inherited from x
    x/ephemeral      compression           zstd-2                        inherited from x
    x/ephemeral      atime                 off                           inherited from x
    x/ephemeral      devices               on                            default
    x/ephemeral      exec                  on                            default
    x/ephemeral      setuid                on                            default
    x/ephemeral      readonly              off                           default
    x/ephemeral      zoned                 off                           default
    x/ephemeral      snapdir               visible                       inherited from x
    x/ephemeral      aclmode               discard                       default
    x/ephemeral      aclinherit            restricted                    default
    x/ephemeral      createtxg             16                            -
    x/ephemeral      canmount              on                            default
    x/ephemeral      xattr                 sa                            inherited from x
    x/ephemeral      copies                1                             default
    x/ephemeral      version               5                             -
    x/ephemeral      utf8only              off                           -
    x/ephemeral      normalization         none                          -
    x/ephemeral      casesensitivity       sensitive                     -
    x/ephemeral      vscan                 off                           default
    x/ephemeral      nbmand                off                           default
    x/ephemeral      sharesmb              off                           default
    x/ephemeral      refquota              none                          default
    x/ephemeral      refreservation        none                          default
    x/ephemeral      guid                  8192812067371941682           -
    x/ephemeral      primarycache          all                           default
    x/ephemeral      secondarycache        all                           default
    x/ephemeral      usedbysnapshots       0B                            -
    x/ephemeral      usedbydataset         98K                           -
    x/ephemeral      usedbychildren        98K                           -
    x/ephemeral      usedbyrefreservation  0B                            -
    x/ephemeral      logbias               latency                       default
    x/ephemeral      objsetid              643                           -
    x/ephemeral      dedup                 edonr,verify                  inherited from x
    x/ephemeral      mlslabel              none                          default
    x/ephemeral      sync                  standard                      default
    x/ephemeral      dnodesize             legacy                        default
    x/ephemeral      refcompressratio      1.00x                         -
    x/ephemeral      written               98K                           -
    x/ephemeral      logicalused           98K                           -
    x/ephemeral      logicalreferenced     49K                           -
    x/ephemeral      volmode               default                       default
    x/ephemeral      filesystem_limit      none                          default
    x/ephemeral      snapshot_limit        0                             local
    x/ephemeral      filesystem_count      1                             local
    x/ephemeral      snapshot_count        0                             local
    x/ephemeral      snapdev               hidden                        default
    x/ephemeral      acltype               off                           default
    x/ephemeral      context               none                          default
    x/ephemeral      fscontext             none                          default
    x/ephemeral      defcontext            none                          default
    x/ephemeral      rootcontext           none                          default
    x/ephemeral      relatime              off                           default
    x/ephemeral      redundant_metadata    most                          inherited from x
    x/ephemeral      overlay               on                            default
    x/ephemeral      encryption            aes-256-gcm                   -
    x/ephemeral      keylocation           none                          default
    x/ephemeral      keyformat             passphrase                    -
    x/ephemeral      pbkdf2iters           350000                        -
    x/ephemeral      encryptionroot        x                             -
    x/ephemeral      keystatus             available                     -
    x/ephemeral      special_small_blocks  0                             default
    x/ephemeral/nix  type                  filesystem                    -
    x/ephemeral/nix  creation              Sat Sep  3 19:40 2022         -
    x/ephemeral/nix  used                  98K                           -
    x/ephemeral/nix  available             123G                          -
    x/ephemeral/nix  referenced            98K                           -
    x/ephemeral/nix  compressratio         1.00x                         -
    x/ephemeral/nix  mounted               no                            -
    x/ephemeral/nix  quota                 none                          default
    x/ephemeral/nix  reservation           none                          default
    x/ephemeral/nix  recordsize            128K                          default
    x/ephemeral/nix  mountpoint            /nix                          local
    x/ephemeral/nix  sharenfs              off                           default
    x/ephemeral/nix  checksum              on                            inherited from x
    x/ephemeral/nix  compression           zstd-2                        inherited from x
    x/ephemeral/nix  atime                 off                           inherited from x
    x/ephemeral/nix  devices               on                            default
    x/ephemeral/nix  exec                  on                            default
    x/ephemeral/nix  setuid                on                            default
    x/ephemeral/nix  readonly              off                           default
    x/ephemeral/nix  zoned                 off                           default
    x/ephemeral/nix  snapdir               visible                       inherited from x
    x/ephemeral/nix  aclmode               discard                       default
    x/ephemeral/nix  aclinherit            restricted                    default
    x/ephemeral/nix  createtxg             34                            -
    x/ephemeral/nix  canmount              on                            default
    x/ephemeral/nix  xattr                 sa                            inherited from x
    x/ephemeral/nix  copies                1                             default
    x/ephemeral/nix  version               5                             -
    x/ephemeral/nix  utf8only              off                           -
    x/ephemeral/nix  normalization         none                          -
    x/ephemeral/nix  casesensitivity       sensitive                     -
    x/ephemeral/nix  vscan                 off                           default
    x/ephemeral/nix  nbmand                off                           default
    x/ephemeral/nix  sharesmb              off                           default
    x/ephemeral/nix  refquota              none                          default
    x/ephemeral/nix  refreservation        none                          default
    x/ephemeral/nix  guid                  15013377728916524076          -
    x/ephemeral/nix  primarycache          all                           default
    x/ephemeral/nix  secondarycache        all                           default
    x/ephemeral/nix  usedbysnapshots       0B                            -
    x/ephemeral/nix  usedbydataset         98K                           -
    x/ephemeral/nix  usedbychildren        0B                            -
    x/ephemeral/nix  usedbyrefreservation  0B                            -
    x/ephemeral/nix  logbias               latency                       default
    x/ephemeral/nix  objsetid              772                           -
    x/ephemeral/nix  dedup                 off                           local
    x/ephemeral/nix  mlslabel              none                          default
    x/ephemeral/nix  sync                  standard                      default
    x/ephemeral/nix  dnodesize             legacy                        default
    x/ephemeral/nix  refcompressratio      1.00x                         -
    x/ephemeral/nix  written               98K                           -
    x/ephemeral/nix  logicalused           49K                           -
    x/ephemeral/nix  logicalreferenced     49K                           -
    x/ephemeral/nix  volmode               default                       default
    x/ephemeral/nix  filesystem_limit      none                          default
    x/ephemeral/nix  snapshot_limit        none                          default
    x/ephemeral/nix  filesystem_count      0                             local
    x/ephemeral/nix  snapshot_count        0                             local
    x/ephemeral/nix  snapdev               hidden                        default
    x/ephemeral/nix  acltype               off                           default
    x/ephemeral/nix  context               none                          default
    x/ephemeral/nix  fscontext             none                          default
    x/ephemeral/nix  defcontext            none                          default
    x/ephemeral/nix  rootcontext           none                          default
    x/ephemeral/nix  relatime              off                           default
    x/ephemeral/nix  redundant_metadata    most                          inherited from x
    x/ephemeral/nix  overlay               on                            default
    x/ephemeral/nix  encryption            aes-256-gcm                   -
    x/ephemeral/nix  keylocation           none                          default
    x/ephemeral/nix  keyformat             passphrase                    -
    x/ephemeral/nix  pbkdf2iters           350000                        -
    x/ephemeral/nix  encryptionroot        x                             -
    x/ephemeral/nix  keystatus             available                     -
    x/ephemeral/nix  special_small_blocks  0                             default
    x/system         type                  filesystem                    -
    x/system         creation              Sat Sep  3 19:40 2022         -
    x/system         used                  198K                          -
    x/system         available             123G                          -
    x/system         referenced            98K                           -
    x/system         compressratio         1.00x                         -
    x/system         mounted               no                            -
    x/system         quota                 none                          default
    x/system         reservation           none                          default
    x/system         recordsize            128K                          default
    x/system         mountpoint            none                          local
    x/system         sharenfs              off                           default
    x/system         checksum              on                            inherited from x
    x/system         compression           zstd-2                        inherited from x
    x/system         atime                 off                           inherited from x
    x/system         devices               on                            default
    x/system         exec                  on                            default
    x/system         setuid                on                            default
    x/system         readonly              off                           default
    x/system         zoned                 off                           default
    x/system         snapdir               visible                       inherited from x
    x/system         aclmode               discard                       default
    x/system         aclinherit            restricted                    default
    x/system         createtxg             23                            -
    x/system         canmount              on                            default
    x/system         xattr                 sa                            inherited from x
    x/system         copies                1                             default
    x/system         version               5                             -
    x/system         utf8only              off                           -
    x/system         normalization         none                          -
    x/system         casesensitivity       sensitive                     -
    x/system         vscan                 off                           default
    x/system         nbmand                off                           default
    x/system         sharesmb              off                           default
    x/system         refquota              none                          default
    x/system         refreservation        none                          default
    x/system         guid                  11008858716627305608          -
    x/system         primarycache          all                           default
    x/system         secondarycache        all                           default
    x/system         usedbysnapshots       0B                            -
    x/system         usedbydataset         98K                           -
    x/system         usedbychildren        100K                          -
    x/system         usedbyrefreservation  0B                            -
    x/system         logbias               latency                       default
    x/system         objsetid              517                           -
    x/system         dedup                 edonr,verify                  inherited from x
    x/system         mlslabel              none                          default
    x/system         sync                  standard                      default
    x/system         dnodesize             legacy                        default
    x/system         refcompressratio      1.00x                         -
    x/system         written               98K                           -
    x/system         logicalused           99K                           -
    x/system         logicalreferenced     49K                           -
    x/system         volmode               default                       default
    x/system         filesystem_limit      none                          default
    x/system         snapshot_limit        none                          default
    x/system         filesystem_count      1                             local
    x/system         snapshot_count        0                             local
    x/system         snapdev               hidden                        default
    x/system         acltype               posix                         local
    x/system         context               none                          default
    x/system         fscontext             none                          default
    x/system         defcontext            none                          default
    x/system         rootcontext           none                          default
    x/system         relatime              off                           default
    x/system         redundant_metadata    most                          inherited from x
    x/system         overlay               on                            default
    x/system         encryption            aes-256-gcm                   -
    x/system         keylocation           none                          default
    x/system         keyformat             passphrase                    -
    x/system         pbkdf2iters           350000                        -
    x/system         encryptionroot        x                             -
    x/system         keystatus             available                     -
    x/system         special_small_blocks  0                             default
    x/user           type                  filesystem                    -
    x/user           creation              Sat Sep  3 19:40 2022         -
    x/user           used                  394K                          -
    x/user           available             123G                          -
    x/user           referenced            98K                           -
    x/user           compressratio         1.00x                         -
    x/user           mounted               no                            -
    x/user           quota                 none                          default
    x/user           reservation           none                          default
    x/user           recordsize            128K                          default
    x/user           mountpoint            none                          local
    x/user           sharenfs              off                           default
    x/user           checksum              on                            inherited from x
    x/user           compression           zstd-2                        inherited from x
    x/user           atime                 off                           inherited from x
    x/user           devices               on                            default
    x/user           exec                  on                            default
    x/user           setuid                on                            default
    x/user           readonly              off                           default
    x/user           zoned                 off                           default
    x/user           snapdir               visible                       inherited from x
    x/user           aclmode               discard                       default
    x/user           aclinherit            restricted                    default
    x/user           createtxg             27                            -
    x/user           canmount              on                            default
    x/user           xattr                 sa                            inherited from x
    x/user           copies                1                             default
    x/user           version               5                             -
    x/user           utf8only              off                           -
    x/user           normalization         none                          -
    x/user           casesensitivity       sensitive                     -
    x/user           vscan                 off                           default
    x/user           nbmand                off                           default
    x/user           sharesmb              off                           default
    x/user           refquota              none                          default
    x/user           refreservation        none                          default
    x/user           guid                  782021205668420263            -
    x/user           primarycache          all                           default
    x/user           secondarycache        all                           default
    x/user           usedbysnapshots       0B                            -
    x/user           usedbydataset         98K                           -
    x/user           usedbychildren        296K                          -
    x/user           usedbyrefreservation  0B                            -
    x/user           logbias               latency                       default
    x/user           objsetid              69                            -
    x/user           dedup                 edonr,verify                  inherited from x
    x/user           mlslabel              none                          default
    x/user           sync                  standard                      default
    x/user           dnodesize             legacy                        default
    x/user           refcompressratio      1.00x                         -
    x/user           written               98K                           -
    x/user           logicalused           197K                          -
    x/user           logicalreferenced     49K                           -
    x/user           volmode               default                       default
    x/user           filesystem_limit      none                          default
    x/user           snapshot_limit        none                          default
    x/user           filesystem_count      3                             local
    x/user           snapshot_count        0                             local
    x/user           snapdev               hidden                        default
    x/user           acltype               off                           default
    x/user           context               none                          default
    x/user           fscontext             none                          default
    x/user           defcontext            none                          default
    x/user           rootcontext           none                          default
    x/user           relatime              off                           default
    x/user           redundant_metadata    most                          inherited from x
    x/user           overlay               on                            default
    x/user           encryption            aes-256-gcm                   -
    x/user           keylocation           none                          default
    x/user           keyformat             passphrase                    -
    x/user           pbkdf2iters           350000                        -
    x/user           encryptionroot        x                             -
    x/user           keystatus             available                     -
    x/user           special_small_blocks  0                             default
    ```
    </details>

4) Finally, mount the filesystems and copy over the keys:

  ```bash
  sudo mkdir -p /mnt

  # Boot and ESP:
  sudo mkdir -p /mnt/boot
  sudo cryptsetup luksOpen /dev/nvme0n1p5 boot-partition -d ./boot.key
  sudo mount /dev/mapper/boot-partition /mnt/boot

  sudo mkdir -p /mnt/boot/efi
  sudo mount /dev/nvme0n1p1 /mnt/boot/efi

  # Root:
  sudo zpool import x -R /mnt
  sudo zfs load-key -L file://$(realpath ./root.key) x
  sudo zfs mount -a

  # Swap (optional):
  sudo swapon /dev/nvme0n1p7
  ```

  ```bash
  sudo mkdir -p /mnt/etc/secrets/
  sudo cp ./root.key ./boot.key /mnt/etc/secrets/
  sudo chmod 000 /mnt/etc/secrets/*.key
  ```

###

re-enable secure boot


ZFS todo:
  - elevator none in the kernel for scheduling since we're not the only partition on the disk
