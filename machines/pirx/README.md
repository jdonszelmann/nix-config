https://en.wikipedia.org/wiki/BD%2B14_4559_b

https://icon-library.com/images/surface-icon/surface-icon-14.jpg

partitions:
  - EFI system partition (512MB)
  - ZFS partition (rest, ~220GB or so)
  - Swap (24 GB)

TODO:
  + list commands
  + run `sfdisk --dump /dev/sda` (pipe output into `sfdisk /dev/sda` to restore)
  + maybe add extra utils (gparted, etc. to the boot partition)

ashift=9: The internal SSD (`HFS256G3AMNB-220`, a 256GB SK Hynix part) has a 512KB block size (`sudo blockdev --getsize /dev/sda`).
default
encryption
  - grub cannot boot from encrypted ZFS
  - but it can boot from LUKS (v1, v2 [with caveats](TODO: link arch wiki page on grub v2 LUKS))
  - so: fat32 ESP, boot drive that's LUKS encrypted, and then the zpool
  - the ESP remains unencrypted/unchecked; secure boot would be the way to be confident that it's not tampered with but that's [tricky](TODO: nixos gh issue about secure boot)
    + the arch linux wiki page about securing the boot partition has some [other suggestions](TODO: link) but none that I think are worth the effort for me personally
  - according to comments on the [ladinu gist](TODO: ...) and on [this Arch Linux forum thread](TODO: link) support for LUKS2 in GRUB is dodgy, even with newer grub versions and PBKDF2
EFI system partition: 512MB
swap: the NixOS ZFS wiki says [not to use a zvol for swap](https://nixos.wiki/wiki/ZFS#Caveats), the `zfs-create` manpage says that swapping to a zvol is fine but *not* to a file on a ZFS filesystem (a dataset). To be safe, we'll just use a separate swap partition that's a real GPT partition outside of the ZFS partition that makes up the vdev
compression on on all (lz4)
dedupe:
  + not on nix store (using autoOptimiseStore so no point really + we have not much RAM)
  + 
2GB max arc cache
  + we don't have much ram


TODO:
  - look into using hardware keys / touch ID for zfs encryption
  - XFS vol for docker?
  - ZRAM swap
  - encrypt swap
