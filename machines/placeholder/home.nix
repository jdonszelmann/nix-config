# optionally, can ask for flake inputs.
{ home-manager, ... }:

{
  system = "x86_64-linux";

  # Can reference modules, mixins here by relative path.
  modules = [
    ../../modules/home-manager/placeholder.nix

    ../../mixins/home-manager/placeholder.nix
  ];

  # Flake inputs are always going to be prepended onto this list anyways though:
  extraSpecialArgs = {};
}