# `home-manager` User Configuration

The idea is that this directory is a `nixos`/`nix-darwin` module that will automatically import home manager configurations based on what users from [`common/users`](../../common/users) are already added to the `nixos`/`nix-darwin` configuration.

Modules within this directory (files ending with `.nix` and directories containing a `default.nix`) are all `home-manager` modules.

TODO: test nix-darwin support!
