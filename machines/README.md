# Machines

`nixos.nix`, `darwin.nix`, `home.nix`

exposed as:
  - `.#nixosConfigurations`
  - `.#darwinConfigurations`
  - `.#homeConfigurations`

TODO: docs about switching, rebuilding, etc. for each kind:
  - nixos:
    + `--flake '.#...'` to `nixos-rebuild` for rebuild
    + `--flake '.#...'` to `nixos-install --root /mnt` for install
    + manually: `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel`
  - nix-darwin: `darwin-rebuild`
    + special bootstrap for flakes: https://github.com/LnL7/nix-darwin#flakes-experimental
    + manually: `nix build .#darwinConfigurations.<hostname>.system`
  - home-manager:
    + https://nix-community.github.io/home-manager/index.html#ch-usage
    + `home-manager switch --flake '.#...'`
    + manually: `nix build .#homeConfigurations.<hostname>.activationPackage`

### Misc Resources

  - nixos:
    + https://nixos.wiki/wiki/NixOS_modules#Under_the_hood

### TODO

list:
  - pirx (surface pro 3): nixos
  - cayahuanca (T15 gen 1): nixos
  - TBN (mbp 18,2)
    + lin: nixos
    + mac: nix-darwin
  - TBN (rpi): nixos
  - TBN (homeserver): nixos
  - wsl: [nixos-wsl](https://github.com/Trundle/NixOS-WSL)
    + inherits all from generic-server?
  - generic-server: home-manager config
    + have the readme explain `nix-user-chroot`/proxy stuff/enter on login stuff
  - vm: qemu thing with generic-server stuff + some accounts?
