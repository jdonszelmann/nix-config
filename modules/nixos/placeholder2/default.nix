{ config, lib, pkgs, flu, ... }: with lib; let
  cfg = config.example.placeholder2;

in {
  imports = [
    ../place/holder/placeholder.nix
  ];

  options.example.placeholder2 = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    example.place.holder.placeholder.enable = import ./helper.nix;
  };
}