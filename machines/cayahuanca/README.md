https://en.wikipedia.org/wiki/HD_52265_b

<!-- "the rock looking at the stars" -->
<!-- commit tag: caya -->

## Machine Info

Model Number: 20S7S

[Product Specifications (PDF)](https://psref.lenovo.com/syspool/Sys/PDF/ThinkPad/ThinkPad_T15_Gen_1/ThinkPad_T15_Gen_1_Spec.PDF)

[Hardware Maintainence Manual (PDF)](https://download.lenovo.com/pccbbs/mobiles_pdf/p15_t15g_gen1_hmm_en.pdf)


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

      # Temporarily copy the key to `/etc/secrets/root.key`:
      sudo mkdir -p /etc/secrets
      sudo cp ./root.key /etc/secrets/root.key

      # Create a pool named `x` on `/dev/nvme0n1p6` with the options above:
      sudo zpool create "${args[@]}" x /dev/nvme0n1p6

      # Delete the key:
      sudo rm -rf /etc/secrets/root.key

      # Create the top-level datasets (but don't mount: -u):
      #
      # A grahamc inspired arrangement, see: https://grahamc.com/blog/nixos-on-zfs
      # And: https://grahamc.com/blog/erase-your-darlings
      ephem_ds_args=(
        # Just a container, don't mount.
        -o mountpoint=none

        x/ephemeral
      )
      sudo zfs create -v -u "${ephem_ds_args[@]}"

      pers_ds_args=(
        -o mountpoint=/persistent

        x/persistent
      )
      sudo zfs create -v -u "${pers_ds_args[@]}"

      # Create the datasets to actually mount:

      # `/`:
      sudo zfs create -v -u -o mountpoint=/ x/ephemeral/root
      # so that things like journalctl work, enable posix acls:
      sudo zfs set acltype=posixacl x/ephemeral/root
      # while it's still pristine:
      sudo zfs snapshot x/ephemeral/root@blank

      # `/nix`:
      sudo zfs create -v -u -o mountpoint=/nix x/ephemeral/nix
      # disable dedupe:
      sudo zfs set dedup=off x/ephemeral/nix
      # disable snapshots:
      sudo zfs set snapshot_limit=0 x/ephemeral/nix
      # use fletcher4? TODO, not sure

      # `/persistent/...`:
      sudo zfs create -v -u x/persistent/home
      sudo zfs create -v -u x/persistent/home/rahul
      sudo zfs create -v -u x/persistent/home/rahul/dev
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
      sudo zfs get all x x/{ephemeral{,/nix,/root},persistent} && \
      sudo zpool export x
    ```
    <details>

    ```
    NAME                          USED  AVAIL     REFER  MOUNTPOINT
    x                            1.15M   123G       98K  none
    x/ephemeral                   294K   123G       98K  none
    x/ephemeral/nix                98K   123G       98K  /nix
    x/ephemeral/root               98K   123G       98K  /
    x/ephemeral/root@blank          0B      -       98K  -
    x/persistent                  392K   123G       98K  /persistent
    x/persistent/home             294K   123G       98K  /persistent/home
    x/persistent/home/rahul       196K   123G       98K  /persistent/home/rahul
    x/persistent/home/rahul/dev    98K   123G       98K  /persistent/home/rahul/dev
    NAME              PROPERTY              VALUE                         SOURCE
    x                 type                  filesystem                    -
    x                 creation              Wed Sep  7  5:29 2022         -
    x                 used                  1.15M                         -
    x                 available             123G                          -
    x                 referenced            98K                           -
    x                 compressratio         1.00x                         -
    x                 mounted               no                            -
    x                 quota                 none                          default
    x                 reservation           none                          default
    x                 recordsize            128K                          default
    x                 mountpoint            none                          local
    x                 sharenfs              off                           default
    x                 checksum              on                            local
    x                 compression           zstd-2                        local
    x                 atime                 off                           local
    x                 devices               on                            default
    x                 exec                  on                            default
    x                 setuid                on                            default
    x                 readonly              off                           default
    x                 zoned                 off                           default
    x                 snapdir               visible                       local
    x                 aclmode               discard                       default
    x                 aclinherit            restricted                    default
    x                 createtxg             1                             -
    x                 canmount              on                            default
    x                 xattr                 sa                            local
    x                 copies                1                             default
    x                 version               5                             -
    x                 utf8only              off                           -
    x                 normalization         none                          -
    x                 casesensitivity       sensitive                     -
    x                 vscan                 off                           default
    x                 nbmand                off                           default
    x                 sharesmb              off                           default
    x                 refquota              none                          default
    x                 refreservation        none                          default
    x                 guid                  8985929508170989259           -
    x                 primarycache          all                           default
    x                 secondarycache        all                           default
    x                 usedbysnapshots       0B                            -
    x                 usedbydataset         98K                           -
    x                 usedbychildren        1.05M                         -
    x                 usedbyrefreservation  0B                            -
    x                 logbias               latency                       default
    x                 objsetid              54                            -
    x                 dedup                 edonr,verify                  local
    x                 mlslabel              none                          default
    x                 sync                  standard                      default
    x                 dnodesize             legacy                        default
    x                 refcompressratio      1.00x                         -
    x                 written               98K                           -
    x                 logicalused           522K                          -
    x                 logicalreferenced     49K                           -
    x                 volmode               default                       default
    x                 filesystem_limit      none                          default
    x                 snapshot_limit        200                           local
    x                 filesystem_count      7                             local
    x                 snapshot_count        1                             local
    x                 snapdev               hidden                        default
    x                 acltype               off                           default
    x                 context               none                          default
    x                 fscontext             none                          default
    x                 defcontext            none                          default
    x                 rootcontext           none                          default
    x                 relatime              off                           default
    x                 redundant_metadata    most                          local
    x                 overlay               on                            default
    x                 encryption            aes-256-gcm                   -
    x                 keylocation           file:///etc/secrets/root.key  local
    x                 keyformat             passphrase                    -
    x                 pbkdf2iters           350000                        -
    x                 encryptionroot        x                             -
    x                 keystatus             available                     -
    x                 special_small_blocks  0                             default
    x/ephemeral       type                  filesystem                    -
    x/ephemeral       creation              Wed Sep  7  5:30 2022         -
    x/ephemeral       used                  294K                          -
    x/ephemeral       available             123G                          -
    x/ephemeral       referenced            98K                           -
    x/ephemeral       compressratio         1.00x                         -
    x/ephemeral       mounted               no                            -
    x/ephemeral       quota                 none                          default
    x/ephemeral       reservation           none                          default
    x/ephemeral       recordsize            128K                          default
    x/ephemeral       mountpoint            none                          local
    x/ephemeral       sharenfs              off                           default
    x/ephemeral       checksum              on                            inherited from x
    x/ephemeral       compression           zstd-2                        inherited from x
    x/ephemeral       atime                 off                           inherited from x
    x/ephemeral       devices               on                            default
    x/ephemeral       exec                  on                            default
    x/ephemeral       setuid                on                            default
    x/ephemeral       readonly              off                           default
    x/ephemeral       zoned                 off                           default
    x/ephemeral       snapdir               visible                       inherited from x
    x/ephemeral       aclmode               discard                       default
    x/ephemeral       aclinherit            restricted                    default
    x/ephemeral       createtxg             9                             -
    x/ephemeral       canmount              on                            default
    x/ephemeral       xattr                 sa                            inherited from x
    x/ephemeral       copies                1                             default
    x/ephemeral       version               5                             -
    x/ephemeral       utf8only              off                           -
    x/ephemeral       normalization         none                          -
    x/ephemeral       casesensitivity       sensitive                     -
    x/ephemeral       vscan                 off                           default
    x/ephemeral       nbmand                off                           default
    x/ephemeral       sharesmb              off                           default
    x/ephemeral       refquota              none                          default
    x/ephemeral       refreservation        none                          default
    x/ephemeral       guid                  11171661559828390350          -
    x/ephemeral       primarycache          all                           default
    x/ephemeral       secondarycache        all                           default
    x/ephemeral       usedbysnapshots       0B                            -
    x/ephemeral       usedbydataset         98K                           -
    x/ephemeral       usedbychildren        196K                          -
    x/ephemeral       usedbyrefreservation  0B                            -
    x/ephemeral       logbias               latency                       default
    x/ephemeral       objsetid              389                           -
    x/ephemeral       dedup                 edonr,verify                  inherited from x
    x/ephemeral       mlslabel              none                          default
    x/ephemeral       sync                  standard                      default
    x/ephemeral       dnodesize             legacy                        default
    x/ephemeral       refcompressratio      1.00x                         -
    x/ephemeral       written               98K                           -
    x/ephemeral       logicalused           147K                          -
    x/ephemeral       logicalreferenced     49K                           -
    x/ephemeral       volmode               default                       default
    x/ephemeral       filesystem_limit      none                          default
    x/ephemeral       snapshot_limit        none                          default
    x/ephemeral       filesystem_count      2                             local
    x/ephemeral       snapshot_count        1                             local
    x/ephemeral       snapdev               hidden                        default
    x/ephemeral       acltype               off                           default
    x/ephemeral       context               none                          default
    x/ephemeral       fscontext             none                          default
    x/ephemeral       defcontext            none                          default
    x/ephemeral       rootcontext           none                          default
    x/ephemeral       relatime              off                           default
    x/ephemeral       redundant_metadata    most                          inherited from x
    x/ephemeral       overlay               on                            default
    x/ephemeral       encryption            aes-256-gcm                   -
    x/ephemeral       keylocation           none                          default
    x/ephemeral       keyformat             passphrase                    -
    x/ephemeral       pbkdf2iters           350000                        -
    x/ephemeral       encryptionroot        x                             -
    x/ephemeral       keystatus             available                     -
    x/ephemeral       special_small_blocks  0                             default
    x/ephemeral/nix   type                  filesystem                    -
    x/ephemeral/nix   creation              Wed Sep  7  5:30 2022         -
    x/ephemeral/nix   used                  98K                           -
    x/ephemeral/nix   available             123G                          -
    x/ephemeral/nix   referenced            98K                           -
    x/ephemeral/nix   compressratio         1.00x                         -
    x/ephemeral/nix   mounted               no                            -
    x/ephemeral/nix   quota                 none                          default
    x/ephemeral/nix   reservation           none                          default
    x/ephemeral/nix   recordsize            128K                          default
    x/ephemeral/nix   mountpoint            /nix                          local
    x/ephemeral/nix   sharenfs              off                           default
    x/ephemeral/nix   checksum              on                            inherited from x
    x/ephemeral/nix   compression           zstd-2                        inherited from x
    x/ephemeral/nix   atime                 off                           inherited from x
    x/ephemeral/nix   devices               on                            default
    x/ephemeral/nix   exec                  on                            default
    x/ephemeral/nix   setuid                on                            default
    x/ephemeral/nix   readonly              off                           default
    x/ephemeral/nix   zoned                 off                           default
    x/ephemeral/nix   snapdir               visible                       inherited from x
    x/ephemeral/nix   aclmode               discard                       default
    x/ephemeral/nix   aclinherit            restricted                    default
    x/ephemeral/nix   createtxg             21                            -
    x/ephemeral/nix   canmount              on                            default
    x/ephemeral/nix   xattr                 sa                            inherited from x
    x/ephemeral/nix   copies                1                             default
    x/ephemeral/nix   version               5                             -
    x/ephemeral/nix   utf8only              off                           -
    x/ephemeral/nix   normalization         none                          -
    x/ephemeral/nix   casesensitivity       sensitive                     -
    x/ephemeral/nix   vscan                 off                           default
    x/ephemeral/nix   nbmand                off                           default
    x/ephemeral/nix   sharesmb              off                           default
    x/ephemeral/nix   refquota              none                          default
    x/ephemeral/nix   refreservation        none                          default
    x/ephemeral/nix   guid                  5320075197706058104           -
    x/ephemeral/nix   primarycache          all                           default
    x/ephemeral/nix   secondarycache        all                           default
    x/ephemeral/nix   usedbysnapshots       0B                            -
    x/ephemeral/nix   usedbydataset         98K                           -
    x/ephemeral/nix   usedbychildren        0B                            -
    x/ephemeral/nix   usedbyrefreservation  0B                            -
    x/ephemeral/nix   logbias               latency                       default
    x/ephemeral/nix   objsetid              268                           -
    x/ephemeral/nix   dedup                 off                           local
    x/ephemeral/nix   mlslabel              none                          default
    x/ephemeral/nix   sync                  standard                      default
    x/ephemeral/nix   dnodesize             legacy                        default
    x/ephemeral/nix   refcompressratio      1.00x                         -
    x/ephemeral/nix   written               98K                           -
    x/ephemeral/nix   logicalused           49K                           -
    x/ephemeral/nix   logicalreferenced     49K                           -
    x/ephemeral/nix   volmode               default                       default
    x/ephemeral/nix   filesystem_limit      none                          default
    x/ephemeral/nix   snapshot_limit        0                             local
    x/ephemeral/nix   filesystem_count      0                             local
    x/ephemeral/nix   snapshot_count        0                             local
    x/ephemeral/nix   snapdev               hidden                        default
    x/ephemeral/nix   acltype               off                           default
    x/ephemeral/nix   context               none                          default
    x/ephemeral/nix   fscontext             none                          default
    x/ephemeral/nix   defcontext            none                          default
    x/ephemeral/nix   rootcontext           none                          default
    x/ephemeral/nix   relatime              off                           default
    x/ephemeral/nix   redundant_metadata    most                          inherited from x
    x/ephemeral/nix   overlay               on                            default
    x/ephemeral/nix   encryption            aes-256-gcm                   -
    x/ephemeral/nix   keylocation           none                          default
    x/ephemeral/nix   keyformat             passphrase                    -
    x/ephemeral/nix   pbkdf2iters           350000                        -
    x/ephemeral/nix   encryptionroot        x                             -
    x/ephemeral/nix   keystatus             available                     -
    x/ephemeral/nix   special_small_blocks  0                             default
    x/ephemeral/root  type                  filesystem                    -
    x/ephemeral/root  creation              Wed Sep  7  5:30 2022         -
    x/ephemeral/root  used                  98K                           -
    x/ephemeral/root  available             123G                          -
    x/ephemeral/root  referenced            98K                           -
    x/ephemeral/root  compressratio         1.00x                         -
    x/ephemeral/root  mounted               no                            -
    x/ephemeral/root  quota                 none                          default
    x/ephemeral/root  reservation           none                          default
    x/ephemeral/root  recordsize            128K                          default
    x/ephemeral/root  mountpoint            /                             local
    x/ephemeral/root  sharenfs              off                           default
    x/ephemeral/root  checksum              on                            inherited from x
    x/ephemeral/root  compression           zstd-2                        inherited from x
    x/ephemeral/root  atime                 off                           inherited from x
    x/ephemeral/root  devices               on                            default
    x/ephemeral/root  exec                  on                            default
    x/ephemeral/root  setuid                on                            default
    x/ephemeral/root  readonly              off                           default
    x/ephemeral/root  zoned                 off                           default
    x/ephemeral/root  snapdir               visible                       inherited from x
    x/ephemeral/root  aclmode               discard                       default
    x/ephemeral/root  aclinherit            restricted                    default
    x/ephemeral/root  createtxg             15                            -
    x/ephemeral/root  canmount              on                            default
    x/ephemeral/root  xattr                 sa                            inherited from x
    x/ephemeral/root  copies                1                             default
    x/ephemeral/root  version               5                             -
    x/ephemeral/root  utf8only              off                           -
    x/ephemeral/root  normalization         none                          -
    x/ephemeral/root  casesensitivity       sensitive                     -
    x/ephemeral/root  vscan                 off                           default
    x/ephemeral/root  nbmand                off                           default
    x/ephemeral/root  sharesmb              off                           default
    x/ephemeral/root  refquota              none                          default
    x/ephemeral/root  refreservation        none                          default
    x/ephemeral/root  guid                  1892533339168872831           -
    x/ephemeral/root  primarycache          all                           default
    x/ephemeral/root  secondarycache        all                           default
    x/ephemeral/root  usedbysnapshots       0B                            -
    x/ephemeral/root  usedbydataset         98K                           -
    x/ephemeral/root  usedbychildren        0B                            -
    x/ephemeral/root  usedbyrefreservation  0B                            -
    x/ephemeral/root  logbias               latency                       default
    x/ephemeral/root  objsetid              516                           -
    x/ephemeral/root  dedup                 edonr,verify                  inherited from x
    x/ephemeral/root  mlslabel              none                          default
    x/ephemeral/root  sync                  standard                      default
    x/ephemeral/root  dnodesize             legacy                        default
    x/ephemeral/root  refcompressratio      1.00x                         -
    x/ephemeral/root  written               0                             -
    x/ephemeral/root  logicalused           49K                           -
    x/ephemeral/root  logicalreferenced     49K                           -
    x/ephemeral/root  volmode               default                       default
    x/ephemeral/root  filesystem_limit      none                          default
    x/ephemeral/root  snapshot_limit        none                          default
    x/ephemeral/root  filesystem_count      0                             local
    x/ephemeral/root  snapshot_count        1                             local
    x/ephemeral/root  snapdev               hidden                        default
    x/ephemeral/root  acltype               posix                         local
    x/ephemeral/root  context               none                          default
    x/ephemeral/root  fscontext             none                          default
    x/ephemeral/root  defcontext            none                          default
    x/ephemeral/root  rootcontext           none                          default
    x/ephemeral/root  relatime              off                           default
    x/ephemeral/root  redundant_metadata    most                          inherited from x
    x/ephemeral/root  overlay               on                            default
    x/ephemeral/root  encryption            aes-256-gcm                   -
    x/ephemeral/root  keylocation           none                          default
    x/ephemeral/root  keyformat             passphrase                    -
    x/ephemeral/root  pbkdf2iters           350000                        -
    x/ephemeral/root  encryptionroot        x                             -
    x/ephemeral/root  keystatus             available                     -
    x/ephemeral/root  special_small_blocks  0                             default
    x/persistent      type                  filesystem                    -
    x/persistent      creation              Wed Sep  7  5:30 2022         -
    x/persistent      used                  392K                          -
    x/persistent      available             123G                          -
    x/persistent      referenced            98K                           -
    x/persistent      compressratio         1.00x                         -
    x/persistent      mounted               no                            -
    x/persistent      quota                 none                          default
    x/persistent      reservation           none                          default
    x/persistent      recordsize            128K                          default
    x/persistent      mountpoint            /persistent                   local
    x/persistent      sharenfs              off                           default
    x/persistent      checksum              on                            inherited from x
    x/persistent      compression           zstd-2                        inherited from x
    x/persistent      atime                 off                           inherited from x
    x/persistent      devices               on                            default
    x/persistent      exec                  on                            default
    x/persistent      setuid                on                            default
    x/persistent      readonly              off                           default
    x/persistent      zoned                 off                           default
    x/persistent      snapdir               visible                       inherited from x
    x/persistent      aclmode               discard                       default
    x/persistent      aclinherit            restricted                    default
    x/persistent      createtxg             11                            -
    x/persistent      canmount              on                            default
    x/persistent      xattr                 sa                            inherited from x
    x/persistent      copies                1                             default
    x/persistent      version               5                             -
    x/persistent      utf8only              off                           -
    x/persistent      normalization         none                          -
    x/persistent      casesensitivity       sensitive                     -
    x/persistent      vscan                 off                           default
    x/persistent      nbmand                off                           default
    x/persistent      sharesmb              off                           default
    x/persistent      refquota              none                          default
    x/persistent      refreservation        none                          default
    x/persistent      guid                  11491495962527013773          -
    x/persistent      primarycache          all                           default
    x/persistent      secondarycache        all                           default
    x/persistent      usedbysnapshots       0B                            -
    x/persistent      usedbydataset         98K                           -
    x/persistent      usedbychildren        294K                          -
    x/persistent      usedbyrefreservation  0B                            -
    x/persistent      logbias               latency                       default
    x/persistent      objsetid              261                           -
    x/persistent      dedup                 edonr,verify                  inherited from x
    x/persistent      mlslabel              none                          default
    x/persistent      sync                  standard                      default
    x/persistent      dnodesize             legacy                        default
    x/persistent      refcompressratio      1.00x                         -
    x/persistent      written               98K                           -
    x/persistent      logicalused           196K                          -
    x/persistent      logicalreferenced     49K                           -
    x/persistent      volmode               default                       default
    x/persistent      filesystem_limit      none                          default
    x/persistent      snapshot_limit        none                          default
    x/persistent      filesystem_count      3                             local
    x/persistent      snapshot_count        0                             local
    x/persistent      snapdev               hidden                        default
    x/persistent      acltype               off                           default
    x/persistent      context               none                          default
    x/persistent      fscontext             none                          default
    x/persistent      defcontext            none                          default
    x/persistent      rootcontext           none                          default
    x/persistent      relatime              off                           default
    x/persistent      redundant_metadata    most                          inherited from x
    x/persistent      overlay               on                            default
    x/persistent      encryption            aes-256-gcm                   -
    x/persistent      keylocation           none                          default
    x/persistent      keyformat             passphrase                    -
    x/persistent      pbkdf2iters           350000                        -
    x/persistent      encryptionroot        x                             -
    x/persistent      keystatus             available                     -
    x/persistent      special_small_blocks  0                             default
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
  sudo mkdir -p /mnt/persistent/etc/secrets/
  sudo cp ./root.key ./boot.key /mnt/persistent/etc/secrets/
  sudo chmod 000 /mnt/persistent/etc/secrets/*.key
  ```

### Other Keys

##### Set Up An SSH Key

  NixOS can generate these for us on boot but we want to rekey our `age` encrypted secrets using the machine's SSH key so that we'll be able to decrypt the secrets on this machine.

  So, we'll generate a new key pair:
  ```bash
  $ ssh-keygen -i cayahuanca -t ed25519
  ```

  And add the public key to [`resources/secrets/pub.nix`](../../resources/secrets/pub.nix) and then rekey our secrets as described [here](../../resources/secrets/).

  Finally, we can move the keypair over to persistent storage on the machine's filesystem:
  ```bash
  $ sudo mv cayahuanca{,.pub} /mnt/persistent/etc/secrets/
  $ sudo chmod 600 /mnt/persistent/etc/secrets/cayahuanca
  ```

##### Secure Boot

TODO: det-sys, switch to systemd-boot

re-enable secure boot


### Build!

`nixos-rebuild .#cayahuanca --root /mnt`

TODO:
  - inline headphone media controls support
    + As per the [product specification PDF](https://psref.lenovo.com/syspool/Sys/PDF/ThinkPad/ThinkPad_T15_Gen_1/ThinkPad_T15_Gen_1_Spec.PDF), this machine has a Realtek ALC3287 codec
    + There is no datasheet available for this codec and Realtek does not acknowledge this chip's existence on its website
    + TODO: add `i2c-dev` to kernel modules and poke around
    + `cat /proc/asound/card0/codec#0` says we're using the driver for the Realtek ALC257
      * which comes from [this file](https://github.com/torvalds/linux/blob/2880e1a175b9f31798f9d9482ee49187f61b5539/sound/pci/hda/patch_realtek.c)
    + links:
      * HDA overview: https://wiki.osdev.org/Intel_High_Definition_Audio
      * HDA spec: https://www.intel.com/content/dam/www/public/us/en/documents/product-specifications/high-definition-audio-specification.pdf
      * https://www.kernel.org/doc/html/latest/sound/hd-audio/notes.html
      * `hda-verb`: https://www.kernel.org/doc/html/latest/sound/hd-audio/notes.html#hda-verb
        - `sudo hda-verb /dev/snd/hwC0D0 0x00 PARAMETERS VENDOR_ID` yields `0x10ec0257` which matches the patch vendor id/device ID for ALC257 [here](https://github.com/torvalds/linux/blob/2880e1a175b9f31798f9d9482ee49187f61b5539/sound/pci/hda/patch_realtek.c#L11768)
    + start by just sweeping the verbs and parameters:
      * `for v in {2000..4095}; do for p in {0..256}; do sudo hda-verb /dev/snd/hwC0D0 0x00 $v $p; done; done`
        - way too slow
      * write a quick C program [based on `hda-verb`](https://github.com/alsa-project/alsa-tools/blob/78e579b3e30076be9e69c410434621b205318dfb/hda-verb/hda-verb.c#L340-L341):
        ```c
        #include <stdio.h>
        #include <stdlib.h>
        #include <string.h>
        #include <ctype.h>
        #include <unistd.h>
        #include <sys/ioctl.h>
        #include <sys/types.h>
        #include <sys/fcntl.h>

        #include <stdint.h>
        typedef uint8_t u8;
        typedef uint16_t u16;
        typedef uint32_t u32;

        // From: https://github.com/alsa-project/alsa-tools/blob/master/hda-verb/hda_hwdep.h
        #define HDA_HWDEP_VERSION	((1 << 16) | (0 << 8) | (0 << 0)) /* 1.0.0 */

        struct hda_verb_ioctl {
          u32 verb;	/* HDA_VERB() */
          u32 res;	/* response */
        };

        static inline u32 hda_verb(u8 node_id, u16 verb, u8 param) {
            return (((u32)node_id) << 24) | (((u32)verb) << 8) | ((u32)param);
        }

        #define HDA_IOCTL_PVERSION       _IOR('H', 0x10, int)
        #define HDA_IOCTL_VERB_WRITE    _IOWR('H', 0x11, struct hda_verb_ioctl)
        #define HDA_IOCTL_GET_WCAP      _IOWR('H', 0x12, struct hda_verb_ioctl)

        int main(int argc, const char** argv) {
            u8 node_id = 0;
            if (argc == 2) {
                node_id = strtol(argv[1], NULL, 0);
            }

            const char* dev = "/dev/snd/hwC0D0";
            const u16 verb_start = 0x800; // 0x0;
            const u16 verb_limit = 0xFFF;
            const u8 param_start = 0;
            const u8 param_limit = 0xFE;
            fprintf(
                stderr,
                "Sweeping `%s` node %d: verbs: { 0x%03X...0x%03X } x params: { 0x%02X...0x%02X }\n",
                dev,
                node_id,
                verb_start, verb_limit,
                param_start, param_limit
            );

            /* Open device. */
            int fd = open(dev, O_RDWR);
          if (fd < 0) {
            perror("open");
            return 1;
          }

            /* Check version. */
            int version = 0;
          if (ioctl(fd, HDA_IOCTL_PVERSION, &version) < 0) {
            perror("ioctl(PVERSION)");
            fprintf(stderr, "Looks like an invalid hwdep device...\n");
            return 1;
          }
          if (version < HDA_HWDEP_VERSION) {
            fprintf(stderr, "Invalid version number 0x%x\n", version);
            fprintf(stderr, "Looks like an invalid hwdep device...\n");
            return 1;
          }


            /* Sweep */
            struct hda_verb_ioctl val;
            for (u16 verb = verb_start; verb <= verb_limit; verb++) {
                for (u8 param = param_start; param <= param_limit; param++) {
                    val.verb = hda_verb(node_id, verb, param);

                    if (ioctl(fd, HDA_IOCTL_VERB_WRITE, &val) < 0) {
                        perror("ioctl");
                        return 2;
                    }
                    if (val.res == 0) { continue; }
                    printf("[0x%03X 0x%02X] = 0x%x\n", verb, param, val.res);
                }

                if (!(verb % 0x100)) fprintf(stderr, "0x%03X...\n", verb);
            }

            close(fd);
        }

        // `for i in {0..50}; do sudo ./a.out $i > a/$(printf "%02d" $i).log; done`
        // Table 141 of the spec is also useful
        ```
        - I think the bash version isn't actually that slow; it's just that verb 0 has long response times (and also puts the codec in a weird state where it starts responding to everything with `0xFFFF`?)
          + putting the machine to sleep and waking it up seems to reset the codec and break it out of this state
        - you can heard the codec going to sleep/waking up based on whether you can hear a faint hiss in your headphones (doesn't seem to affect the speed since the timeout to sleep seems to be ~1s but if you play music while running the above the codec will stay awake)

    https://bbs.archlinux.org/viewtopic.php?id=231478
    lots of ppl asking this Q, no answers though

    some codecs with support in the linux kernel clearly support headphone button presses: https://github.com/torvalds/linux/blob/master/sound/soc/codecs/nau8825.c
    but no HDA codecs, it seems: https://cs.github.com/torvalds/linux?q=SND_JACK_BTN_0 https://cs.github.com/torvalds/linux?q=snd_jack_set_key https://cs.github.com/torvalds/linux?q=snd_jack+path%3A%2F%5Esound%5C%2Fpci%5C%2Fhda%2F


    `sudo hda-verb /dev/snd/hwC0D0 0x19 0xF09 0` is headphone mic detection (0x8000000 when plugged in, 0 otherwise), `0x21` is headphone out detection

    trying the obvious interfaces (GPIO, GPI registers) did not yield anything either (GPIO enable and data do work and do seem to indicate that there are three GPIO pins but reading them doesn't yield anything useful; pins 0 and 1 seem to be stuck high and none of the pins seem to change in reponse to any stimulus)

    diffing the register dumps of the first 40 node ids (the entire "get" verb, all parameters space) with the buttons pressed/not pressed yields nothing also (was hoping that some of the "vendor defined widget" nodes might've had the goods)

    haven't been able to find any Intel HDA codecs supported by the kernel and/or with public datasheets that have support for or hint at the interface for inline headphone buttons
      - ChromeOS and android devices both definitely have support for these but they both seem to use "soc" codecs instead of intel HDA codecs
        + as far as I can tell there is no overlap between these kinds of codecs
        + there _are_ chromeOS laptops that ship Intel processors and thus _probably_ use Intel HDA (and probably support inline headphone buttons?) but: a quick glance through the commits on `sound/pci/hda` in the chrome os kernel fork revealed nothing relevant: https://chromium.googlesource.com/chromiumos/third_party/kernel/+log/refs/heads/chromeos-5.4/sound/pci/hda?s=5f68b0ec9882112864b05cab49c72d6cb7745f35

    hmm: https://patchwork.kernel.org/project/alsa-devel/patch/20190220115732.16216-2-tiwai@suse.de/
    hmmmmm: https://patchwork.kernel.org/project/alsa-devel/patch/20210305092608.109599-1-hui.wang@canonical.com/

    given that I haven't been able to find prior art and I haven't been able to stumble into the interface by probing the registers, I think this means we'll need to do some reverse engineering

    doing things at the hardware level seems impractical:
      - I don't know of any economical and unintrusive ways to introspect PCI traffic (which we'd need to do for HDA)
      - and I don't have the tools to prod at pins on the actual codec chip and collect traffic that way (and I don't really feel comfortable doing this on this device anyways given that we'd need to do some experimentation to figure out the pinout of the chip)

    static reverse engineering of the driver is an option but:
      - I don't have enough reverse engineering experience (and enough of an understanding of Windows drivers) for this to be practical
      - the realtek windows audio codec driver blob is ~90MB

    quick searches didn't manage to dig up any kind of documentation for windows HDA/codec drivers and I wasn't able to find any obvious ways that windows offers to hook onto such drivers for debugging

    so, I think that leaves virtualization
      - we can run windows in a VM, with the realtek drivers
      - and expose a "fake" Intel HDA controller with our codec
        + either proxied to the real codec chip or backed by a software facsimile
    this will let us capture full traces of the commands the windows driver issues to the codec

    I think this isn't _too_ hard to do with QEMU
      - it supports [windows guests (with audio support)](https://wiki.gentoo.org/wiki/QEMU/Windows_guest)
      - and has an [Intel HDA device](https://github.com/qemu/qemu/blob/afdb415e67e13e8726edc21238c9883447b2c704/hw/audio/intel-hda.c) and a [codec device](https://github.com/qemu/qemu/blob/266469947161aa10b1d36843580d369d5aa38589/hw/audio/hda-codec.c) (also [here](https://github.com/qemu/qemu/blob/266469947161aa10b1d36843580d369d5aa38589/hw/audio/hda-codec-common.h)) which we can modify
      - there's definitely [precedent](https://www.apriorit.com/dev-blog/589-develop-windows-driver-using-qemu)
      - and passing through the entire PCI device and tracing I/O accesses is also [an option](https://digriz.org.uk/tutorials/reversing-pci-drivers) (more [here](https://hakzsam.wordpress.com/2015/02/21/471/))
      - actually [this repo](https://github.com/Conmanx360/QemuHDADump) describes [how to do this](https://github.com/Conmanx360/QemuHDADump/wiki/Setup-and-usage-of-the-program) specifically for HDA sound cards and codecs and has tooling that goes and parses the actual HDA gets and sets

system debugging packages:
  - dmidecode
  - `i2c-dev` to kernel modules
  - lsusb, lspci
  - i2c-tools
  - aplay?
  - libinput
  - alsa-tools (hda-verb)

bp:
  - ALC3287 inline mic controls
  - TI USB ICDI?
  - RE Intel DMC
