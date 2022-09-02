# Modules

Home to [NixOS modules](nixos), [`nix-darwin` modules](darwin), and [`home-manager` modules](home-manager).

Modules can have one of the following forms:
  - files ending with `.nix`, potentially nested within directories
  - directories containing a `default.nix`
    + note that such directories will not be searched for _other_ modules (i.e. if a directory has `foo.nix` as well as `default.nix`, `foo.nix` will not be picked up as a module)

Note that these modules cannot ask for flake inputs in a separate attrset like some other components in this repo can; instead flake inputs should be requested along with the other attrs for the module.

[`flake.nix`](../flake.nix) takes care to thread in the flake inputs to each of these module systems (`extraArgs` for NixOS modules, `inputs` for `nix-darwin`, `extraSpecialArgs` for `home-manager` modules).