{ config, lib, util, pkgs, ... }: let
  jsonc = util.read-jsonc;
in {
  programs.vscode = {
    enable = true;

    # `lib.flatten (lib.mapAttrsToList (n: v: if (builtins.typeOf v) == "set" then (builtins.map (a: "${n}.${builtins.toString a}") (builtins.attrNames v)) else []) np.vscode-extensions)` to list extensions
    extensions = with pkgs.vscode-extensions; let
      # TODO: add this directly to the direnv-vscode repo's flake?
      # https://github.com/direnv/direnv-vscode/blob/main/flake.nix
      #
      # or add to nixpkgs
      direnv = pkgs.vscode-utils.extensionFromVscodeMarketplace {
        name = "direnv";
        publisher = "mkhl";
        version = "0.6.1";
        sha256 = "sha256-5/Tqpn/7byl+z2ATflgKV1+rhdqj+XMEZNbGwDmGwLQ=";
      };
    in [
      jnoortheen.nix-ide
      eamodio.gitlens
      bbenoist.nix
      mikestead.dotenv
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

      bierner.markdown-mermaid
      # TODO: bpruitt-goddard.mermaid-markdown-syntax-highlighting

      twxs.cmake # just CMake grammar + lang support
      # ms-vscode.cmake-tools # heavy, has build sys integration

      direnv
      # cortex-debug.svd-viewer
      # marus25.cortex-

      # TODO: tintinweb.graphviz-interactive-preview

      # TODO: x86 instruction reference by whiteout
      # TODO: x86_64 assembly by 13xforever
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
