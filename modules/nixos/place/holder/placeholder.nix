{ config, lib, pkgs, flu, ... }: with lib; let
  cfg = config.example.place.holder.placeholder;

in {
  options.example.place.holder.placeholder = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    programs.zsh.shellInit = ''
      echo "hello from place.holder.placeholder!"
    '';
  };
}