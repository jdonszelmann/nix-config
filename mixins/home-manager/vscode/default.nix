{ config, lib, util, pkgs, ... }: let
  jsonc = util.read-jsonc {inherit lib;};
in {
  programs.vscode = {
    enable = true;

    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      eamodio.gitlens
      bbenoist.nix
      mikestead.dotenv # TODO: direnv
      bungcip.better-toml
      usernamehw.errorlens
      timonwong.shellcheck
      matklad.rust-analyzer
      # kamadorueda.alejandra
      alefragnani.bookmarks
      naumovs.color-highlight
      shardulm94.trailing-spaces
      ms-vsliveshare.vsliveshare
      github.github-vscode-theme
      stkb.rewrap

      streetsidesoftware.code-spell-checker
      ms-vscode-remote.remote-ssh
      llvm-vs-code-extensions.vscode-clangd

      ms-python.python
      ms-python.vscode-pylance

      # cortex-debug.svd-viewer
      # marus25.cortex-debug
    ];

    keybindings = let
      base = jsonc ./keybindings.jsonc;
      terminalFocus = let
        template = n: {
          key = "alt+${toString n}";
          command = "workbench.action.terminal.focusAtIndex${toString n}";
          when = "terminalFocus";
        };
      in
        builtins.map template (lib.range 1 9);
    in
      base ++ terminalFocus;
    userSettings = jsonc ./settings.jsonc;
  };
}
