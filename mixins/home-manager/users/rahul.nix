{ config, pkgs, ... }:

{
  imports = [
    ../../../modules/home-manager/impermanence.nix
  ];

  rrbutani.impermanence.extra = {
    dirs = [
      "downloads"
      "documents"
      "dev"
    ];
    files = [
      ".zsh_history"
      ".bash_history"
    ];
  };

  home = rec {
    username = "rahul";
    homeDirectory = "/home/${username}";

    stateVersion = "22.11";
  };

  programs.home-manager.enable = true;
}
