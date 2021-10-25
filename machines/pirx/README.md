https://en.wikipedia.org/wiki/BD%2B14_4559_b

https://icon-library.com/images/surface-icon/surface-icon-14.jpg

partitions:
  - EFI system partition (512MB)
  - Boot partition (5GB)
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
  - `cryptsetup benchmark` seems to indicate that aes-xtb 256b/512b performs the best on this device
  - for the ZFS volumes we can use pool level encryption or dataset level encryption; for simplicity we just use pool level encryption here
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
  - look into pw retry in GRUB for LUKS that's not painful


## Setup

### Filesystems

1) First, set up `/dev/sda1` (the internal 256GB `HFS256G3AMNB-220` SSD) with a GPT partition table and the partitions described above.
   When finished the drive's partition table should look like this:

   ```bash
   # First, set up 
   ```

   In the future, `sfdisk /dev/sda < /path/to/file/containing/the/above` can be used to set up the drive as above.

2) Next let's set up some keys for full disk encryption.

   As mentioned above, we use LUKS1 to encrypt the `/boot` partition and ZFS' built-in pool level encryption.

   Some notes:
    - LUKS [uses a _master-key_](TODO: arch Device_encryption#Cryptsetup_passphrases_and_keys link); a password is used to unlock the _master-key_ which then is used to decrypt the drive. A side-effect of this is that there can be multiple keys (`cryptsetup` docs call these _passphrases_) which we take advantage of.
    - Similar to the setup detailed in [`@ladinu`'s gist]:
      + We use two keys and one passphrase:
        * one passphrase for us to enter at boot; GRUB will use this to decrypt a filesystem containing the kernel (`/` in the case of the gist, `/boot` for us)
        * one key for the filesystem that GRUB needs to access (`/` in the case of the gist, `/boot` for us)
          - we need this key for NixOS to be able to access the filesystem _without_ us having to enter the password again (when control is handed off from GRUB to the initial ram disk the filesystem needs to be opened again)
        * another key for the "other" filesystem (`/data` in the gist, `/` for us)
      + The first key (for `/boot`) is stored in a slot on the LUKS device
        * this key — a _master-key_ — can be used by GRUB in conjunction with the passphrase
   
