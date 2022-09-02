{ config, pkgs, ... }:

{
  home = rec {
    username = "example";
    homeDirectory = "/home/${username}";

    stateVersion = "22.11";
  };

  programs.home-manager.enable = true;
}