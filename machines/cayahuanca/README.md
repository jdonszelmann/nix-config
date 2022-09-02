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

(follows the [instructions for `pirx`](../pirx/README.md))

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