https://en.wikipedia.org/wiki/BD%2B14_4559_b

https://icon-library.com/images/surface-icon/surface-icon-14.jpg

partitions:
  - EFI system partition (512MB)
  - Boot partition (5GB)
  - ZFS partition (rest, ~209GB or so)
  - Swap (24 GB)

TODO: diagram in the style of: https://gist.github.com/rrbutani/0934dd9fc89d55cf65f9a0775c59a215

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
  - look into using hardware keys / touch ID for zfs encryption/boot encryption
    + storing keys in a TPM is also [a thing](https://wiki.archlinux.org/title/Trusted_Platform_Module#Data-at-rest_encryption_with_LUKS)
      * I think the appeal is that you don't have to enter a password to unlock, for example, the boot drive; provided Secure Boot works and is happy your boot drive can just automatically unlock
      * I think this is supposed to be similar to how BitLocker works on Windows
      * Given that it's tricky to get Secure Boot working with NixOS and that I don't mind having to enter a password on boot, I'm going to ignore this
    + LUKS (and nixos' initrd) seem to have support for yubikeys; something to look into later
  - XFS vol for docker?
    + Using XFS for `/var/lib/docker` is recommended [so that you can the `overlay2` storage driver](https://docs.docker.com/storage/storagedriver/overlayfs-driver/#configure-docker-with-the-overlay-or-overlay2-storage-driver)
      * ext4 seems to work too
    + It seems easy enough to stick XFS on another partition or on a fixed sized zvol in the pool
    + There's also a [ZFS storage driver for Docker](https://docs.docker.com/storage/storagedriver/zfs-driver/)
      * despite what that page suggests, I think it's also possible to use the Docker ZFS storage driver [with a dataset on an existing zpool](https://dker.ru/docs/docker-engine/user-guide/docker-storage-drivers/zfs-storage-in-practice/); I don't think you actually have to give it a whole zpool
    + Another option is to just run with the `vfs` storage driver backed by just a folder on a ZFS dataset but that seems bad
  - ZRAM swap
  - encrypt swap
  - look into pw retry in GRUB for LUKS that's not painful
  - backup: https://zfs.rent/
    + regardless of what backup solution is used: remember to use `-w` with send! (TODO)
  - [`sanoid`](https://github.com/jimsalterjrs/sanoid/) looks neat for backups
    + and it has [a nixpkg](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/backup/sanoid.nix)
  - set up mailing for ZED

## Setup

### Filesystems

1) First, set up `/dev/sda1` (the internal 256GB `HFS256G3AMNB-220` SSD) with a GPT partition table and the partitions described above.
   When finished the drive's partition table should look like this:

   ```bash
   $ sudo sfdisk --dump /dev/sda
   label: gpt
   label-id: BBE6F52B-5986-477A-93D4-914C531EEF5F
   device: /dev/sda
   unit: sectors
   first-lba: 34
   last-lba: 500118158
   sector-size: 512

   /dev/sda1 : start=        2048, size=     1048576, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, uuid=4567C05E-559F-4F10-A2E6-5D98DA1B53B2, name="EFI System Partition"
   /dev/sda2 : start=     1050624, size=    10485760, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=CB382612-A2AF-4FBC-87CB-A68A49ED7E86, name="boot"
   /dev/sda3 : start=    11536384, size=   438249472, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=7B032494-5FC8-460B-BEE5-5A410D518516, name="root"
   /dev/sda4 : start=   449785856, size=    50331648, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, uuid=8E8506B3-2648-49FC-BF19-47CEE8CF7FD5, name="swap"
   ```

   NOTE: there are reports of versions of the debian installer mangling partitions with type `8300`; I can't find the forum post where I saw < but maybe be careful.

   In the future, `sfdisk /dev/sda < /path/to/file/containing/the/above` can be used to set up the drive as above.

2) Next let's set up some keys for encryption.

   As mentioned above, we use LUKS1 to encrypt the `/boot` partition and ZFS' built-in pool level encryption.

   Some notes:
    - LUKS [uses a _master-key_](TODO: arch Device_encryption#Cryptsetup_passphrases_and_keys link); a key/password is used to unlock the _master-key_ which then is used to decrypt the drive. A side-effect of this is that there can be multiple keys/passwords (`cryptsetup` docs call these _passphrases_) which we take advantage of ([this StackExchange post](https://crypto.stackexchange.com/questions/89283/how-does-luks-encrypt-the-master-key) has more details about how this works if you're curious).
    - Similar to the setup detailed in [`@ladinu`'s gist](https://gist.github.com/ladinu/bfebdd90a5afd45dec811296016b2a3f):
      + We use two keys and one password:
        * one password for us to enter at boot; GRUB will use this to decrypt a filesystem containing the kernel (`/` in the case of the gist, `/boot` for us)
        * one key for the filesystem that GRUB needs to access (`/` in the case of the gist, `/boot` for us)
          - we need this key for NixOS to be able to access the filesystem _without_ us having to enter the password again (when control is handed off from GRUB to the initial ram disk the filesystem needs to be opened again)
        * another key for the "other" filesystem (`/data` in the gist, `/` for us)
      + The `/boot` partition will have two "passphrases" associated with it: the first key as well as the password
        * you can see what _slots_ on a LUKS partition are in use with `cryptsetup luksDump <device>`
      + The `/` zvol will be encrypted using the second key
        * though ZFS seems to also use a master key (see [this](https://openzfs.github.io/openzfs-docs/man/8/zfs-change-key.8.html)) it does not seem to have an equivalent to LUKS' slots
        * [the Ars guide](https://arstechnica.com/gadgets/2021/06/a-quick-start-guide-to-openzfs-native-encryption/) also says that the `keylocation` is baked in and not easy to change, but it also notes that the [`-L` option on `zfs load-key`](https://openzfs.github.io/openzfs-docs/man/8/zfs-load-key.8.html?highlight=-L%20keylocation) can effectively override this
        * my concern was being able to easily unlock zvols "by hand", i.e. using a passphrase (this isn't important for this machine's setup but is nice to have for dual boot setups with a data filesystem)
          - being able to enter the "key" by hand means that you can effectively pick a password and have it be your key
      + Both the keys are stored in the initial ram file system (initramfs) so that, once GRUB has loaded the initramfs, the initramfs can unlock the `/boot` and `/` filesystems
        * this is okay! `/boot` (the filesystem holding the initramfs) is itself encrypted which is what makes this still secure

   Okay! With that out of the way let's make some keys:
   ```bash
   # LUKS keys can be up to 8192KiB: https://wiki.archlinux.org/title/dm-crypt/Device_encryption#Cryptsetup_passphrases_and_keys
   #
   # We'll go with a nice round 512B to match ZFS.
   $ dd if=/dev/urandom of=./boot.key bs=512 count=1

   # ZFS keys (when not using raw/hex keys; see here and search for "keyformat=": https://openzfs.github.io/openzfs-docs/man/7/zfsprops.7.html?highlight=keyformat)
   # can be up to 512B long.
   $ dd if=/dev/urandom of=./root.key bs=512 count=1
   ```

   You can store these keys in a secure place if you wish. Alternatively, you can generate these keys [onto a ramdisk](https://wiki.archlinux.org/title/dm-crypt/Device_encryption#Storing_the_keyfile_in_ramfs) so there is no potential trace of them on your current filesystem(s).

3) Now let's make some partitions. In order:
    - EFI System Partition:
      + First let's set this to actually be an EFI System Partition:
        * `sudo fdisk /dev/sda`
          - `t` to change a partition type
          - `1` to select the first partition
          - `uefi` to use the EFI System Partition type (`0xEF`)
          - `w` to write out the updated partition table
      + Then we can actually make the filesystem:
        * `sudo mkfs.fat -F 32 /dev/sda1`

    - Boot:
      + First let's set this to be an opaque "Linux" partition type so things that don't understand LUKS don't break:
        * `sudo fdisk /dev/sda`
          - `t` to change a partition type
          - `2` to select the second partition
          - `linux` to use the Linux partition type (`0x83`)
          - `w` to write out the updated partition table
      + Next, we can set up LUKS ([1](https://wiki.archlinux.org/title/dm-crypt/Device_encryption#Encryption_options_with_dm-crypt), [2](https://gist.github.com/ladinu/bfebdd90a5afd45dec811296016b2a3f#setup-luks-and-add-the-keys), [3](https://linux.die.net/man/8/cryptsetup)):
        ```bash
        $ args=(
            --type=luks1              # GRUB support for LUKS2 is still dodgy, even with the right key and cipher
                                      # See: https://bbs.archlinux.org/viewtopic.php?id=268460

            --cipher=aes-xts-plain64  # According to `cryptsetup bench`, `aes-xts` w/a 256 key is fastest
            --key-size=256

            --hash=sha256
            --use-urandom

            --iter-time=2000          # Time spent doing PBKDF2 iterations; an exact count is derived from this, I think

            --verify-passphrase

            --sector-size=512         # Sector size for this device is 512B as mentioned above
        )

        # This will prompt you for a password. This will be the password you'll need to enter at boot.
        $ cryptsetup luksFormat "${args[@]}" /dev/sda2

        # Next we'll add the keyfile as well:
        $ cryptsetup luksAddKey /dev/sda2 ./boot.key
        ```

   - Root:
     + First let's set this to a Solaris partition type:

     ([1](https://nixos.wiki/wiki/ZFS), [2](https://arstechnica.com/information-technology/2020/05/zfs-101-understanding-zfs-storage-and-performance/), [3](zhttps://openzfs.github.io/openzfs-docs/man/8/zpool-create.8.html), [4](https://openzfs.github.io/openzfs-docs/man/7/zpool-features.7.html). [5](https://openzfs.github.io/openzfs-docs/man/7/zpoolprops.7.html))
     -o `pbkdf2iters` iterations from `cryptsetup bench` to match ^ (2000 ms)
     encryption on, passphrase, file source
     compression on, lz4
     datasets:
       - /, nixstore, home?, docker, data
     compression off on nixstore, docker
     reserved
     atime off, xattrs on, etc.
     snapshots on, off on nixstore, docker
     trim on; scheduled cleanup
     -o comment

     pool name: x


   - Swap:
     + First the partition type:
       * `sudo fdisk /dev/sda`
         - `t` to change a partition type
         - `4` to select the fourth partition
         - `swap` to use the Swap partition type (`0x82`)
         - `w` to write out the updated partition table
     + Finally: `sudo mkswap -L swap /dev/sda4`
