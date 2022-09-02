{ system }:
{ home-manager, ... }:

{
  inherit system;

  modules = [
    # TODO!
    ../../../mixins/home-manager/placeholder.nix
  ];
}