# `age` Encrypted Secrets

Run `ragenix` with `nix run ../..#ragenix`.

Pass in `-i <path/to/key>` explicitly if a key used to create the secrets is not in `~/.ssh`.

#### Updating Public Keys

After adding new public keys to [`pub.nix`](pub.key) or changing the key configuration in [`secrets.nix`](secrets.nix), rekey with `nix run ../..#ragenix -- --rekey`.

#### Adding New Secrets

1) Add your secret to [`secrets.nix`](secrets.nix) and choose which keys can decrypt the secret.

2) Create the secret with `nix run ../..#ragenix -- --edit <secret.age>`.
  - you can set `$EDITOR` or use `--editor`; i.e. `EDITOR="code -w"`

##### Adding Binary Secrets

For secrets containing text data, firing up an editor works great but this is less convenient for secrets that consist of binary data.

Fortunately we can (ab)use `--editor` for this:
  - to write:
    ```bash
    echo -n "shhhhh!" | nix run ../..#ragenix -- --edit secret.age --editor tee >/dev/null
    ```
  - to read:
    ```bash
    # Note: ragenix emits warnings on `stdout` which makes this unsuitable for piping
    # out to a file!
    nix run ../..#ragenix -- --edit secret.age --editor cat

    # Instead, if you need to recreate the unencrypted file, use this:
    nix run ../..#ragenix -- --edit secret.age --editor "cp -t ."; cat input
    ```

<!-- `mkpasswd --stdin --method=sha-256 | nix run ../..#ragenix -- --edit r-pass.age --editor tee` -->

#### Updating Secrets

Just need to do step 2 above. This _will_ require decrypting first so you'll need to pass in a key that can be used to decrypt the secret with `-i` if it's not already in `~/.ssh`.
