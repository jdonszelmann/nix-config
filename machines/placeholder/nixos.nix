# optionally, can ask for flake inputs.
inputs@{ home-manager, ... }:

{
  system = "x86_64-linux";

  # Can reference modules, mixins here by relative path.
  modules = [
    # Add the home-manager module and make the flake inputs accessible to
    # home-manager modules:
    home-manager.nixosModules.home-manager
    {
      home-manager = {
        extraSpecialArgs = inputs;
        useUserPackages = true;
        useGlobalPkgs = true;
        users.example = import ../../mixins/home-manager/placeholder.nix;
      };
    }

    ../../modules/nixos/placeholder.nix
    {
      users.users.example = {
        home = "/home/example";
        isNormalUser = true;
        group = "example";
      };

      fileSystems."/" = {
        device = "tmpfs";
        fsType = "tmpfs";
      };
      boot.loader.grub.devices = [ "nodev" ];

      system.stateVersion = "22.11";
    }
  ];

  # Flake inputs are always going to be prepended onto this set anyways though:
  specialArgs = {};
}