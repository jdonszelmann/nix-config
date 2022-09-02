# Overlays

Home to some [`nixpkgs` overlays](https://nixos.wiki/wiki/Overlays).

These can be single files ending with `.nix` or directories containing a `default.nix`.

### Interface

These can have either the standard overlay interface:
```nix
final: prev: { ... }
```

Or can take flake inputs:
```nix
{ ragenix
, flu
, ...
}:

final: prev: { ... }
```

### Usage

Use through the `.overlays` key on the flake at the root of this repo.