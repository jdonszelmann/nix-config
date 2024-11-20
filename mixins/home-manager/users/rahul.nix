inputs@{ config, pkgs, ragenix, system, nix-index-database,
  ...
}: {
  imports = [
    ../../../modules/home-manager/impermanence.nix

    ../vscode

    # <work.nix>

    nix-index-database.hmModules.nix-index
  ];


  rrbutani.impermanence.extra = {
    dirs = [
      "downloads"
      "documents"
      # { directory = "dev"; /* method = "bindfs"; */ }

      # TODO: move to VSCode, narrow?
      # ".config/Code/User/"
      ".config/Code/User/History/"
      ".config/Code/User/workspaceStorage"
      ".config/Code/User/globalStorage"

      # ".config/Code/Backups/workspaces.json"
      ".config/Code/Backups/"
      ".config/Code/databases"

      ".mozilla/firefox" # TODO: narrow

      # TODO: narrow, spin off
      # See: https://github.com/IsmaelMartinez/teams-for-linux/blob/f02846e0894432553e7bcc1e9c8f290a44f4eaf7/KNOWN_ISSUES.md#config-folder-locations
      # ".config/teams"
      # ".config/Microsoft/"

      # TODO: fix, spotify just overwrites `prefs` instead of
      # modifying via the symlink which makes home-manager sad
      ".config/spotify"
      # ".config/spotify/prefs"
      # ".config/spotify/Users"

      # Cargo:
      # TODO: switch to managing the .cargo/config file ourselves +
      # ditch this registry entry when `sparse-registry` hits stable!
      ".cargo/registry"
      ".cargo/config.toml"

      # TODO:
      # /var/lib/systemd/coredump?
    ];
    files = [
      "dev" # :shrug:
      ".zsh_history"
      ".bash_history"
      ".ssh/known_hosts"

      # TODO: .bazelrc with `--disk_cache=/nix/var/cache/bazel`
    ];
  };

  # TODO: gate on linux
  xdg.userDirs = {
    enable = true;
    desktop = "/dev/null";
    documents = "$HOME/documents";
    download = "$HOME/downloads";
    music = "/dev/null";
    # pictures = "/dev/null";
    pictures = "$HOME/downloads"; # TODO: actually just go set this for the gnome screenshot tool?

    publicShare = "/dev/null";
    templates = "/dev/null";
    videos = "/dev/null";
  };

  # `dev` entry in sidebar in file explorer
  gtk.gtk3.bookmarks = [
    "file:///home/${config.home.username}/dev"
    "file:///tmp"
  ];

  home = rec {
    username = "rahul";
    homeDirectory = "/home/${username}";

    stateVersion = "22.11";
  };

  home.packages = with pkgs; [
    fd
    nil
    # ragenix.packages.${system}.ragenix # not needed, don't use this that often


    # Until https://github.com/NixOS/nixpkgs/commit/a51f9c5c1ca965c2dd3780d86692ce7766cc0930
    # makes its way into `nixos-unstable`:
    #
    # https://nixpk.gs/pr-tracker.html?pr=216332
    (spotify.override {
      # ffmpeg = (ffmpeg.overrideAttrs (final: prev: { passthru.out = final.finalPackage.lib; }));
    })

    mosh

    ripgrep
    moreutils

    # TODO: overlay to update tokei?
    # See: https://github.com/XAMPPRocky/tokei/issues/911
    # I mainly just want bazel support: https://github.com/XAMPPRocky/tokei/pull/999
    tokei

    # bottom
    dog


    diskonaut # TODO: ncdu? dust?
    nix-output-monitor nix-du nix-tree nix-diff

    #

    eyedropper

    # TODO: duf, procs, etc.

    # TODO: targo or something like it: https://github.com/sunshowers/targo
    # i.e. a way for crago to put its build dir on non-persistent storage!
    #
    # https://github.com/rust-lang/cargo/issues/11156
  ];

  programs.home-manager.enable = true;

  # nix.registry = # TODO
  nix.settings = {
    # TODO: move to system config
    inherit ((import ../../../flake.nix).nixConfig)
      # extra-substituters
      extra-trusted-public-keys;
  };
  # nix.package = pkgs.nixUnstable;

  programs = {
    # TODO: alacritty? kitty?

    zsh.enable = true;
    bash = {
      enable = true;
      # bashrcExtra = ""; # TODO
      # TODO: move to vscode config, replicate for zsh?
      bashrcExtra = ''
        if [[ "$TERM_PROGRAM" == "vscode" ]]; then
          export EDITOR="code -w"
        fi
      '';
      initExtra = ''
        buildOn() {
          local drv="$(cat -)"
          nix-copy-closure --to $1 "$drv"
          ssh $1 nom build "$drv"
        }
      '';
      historyControl = ["ignorespace" "erasedups"];
      historyFileSize = -1;
      historySize = -1;
      # TODO: HISTTIMEFORMAT
      shellAliases = {
        cat = "bat";
        # ls = "exa";
        # ll = "ls --color -l"; # TODO: grab and mkForce
        # TODO

        # TODO: no `nix-env`! disable it

        open = "xdg-open"; # TODO: gate on macOS
      };
    };
    # TODO: configure ^

    # home-manager.enable = true; # TODO
    firefox.enable = true; # TODO: extensions, etc
    bat.enable = true; # TODO: themes, etc.
    bottom.enable = true;
    dircolors.enable = true; # TODO: colors
    direnv.enable = true; # TODO
    direnv.nix-direnv.enable = true;
    eza.enable = true;
    eza.enableAliases = true;
    feh.enable = true; # TODO
    fzf = {
      enable = true;
      # TODO: configure;
      changeDirWidgetCommand = "fd --type d";
      defaultCommand = "fd --type f";
    };

    # TODO: gh


    # TODO: in direnv enable, add `.direnv` to global gitignore
    git = {
      enable = true;
      aliases = {
        staged = "diff --cached";
      };
      attributes = [
        "*.age diff=age"
      ];
      delta = {
        enable = true;
        options = {}; # TODO
      };
      extraConfig = {
        # user = {
        # email = "rrbutani@users.noreply.github.com";
        # name = "Rahul Butani";
        # signingKey = (import ../../resources/secrets/pub.nix).rahul;
        # };
        # commit = {
        # gpgSign = true;
        # };
        # tag = {
        # gpgSign = true;
        # }
        gpg.format = "ssh";
        diff = {
          age.textconv = "${pkgs.rage}/bin/rage --decrypt -i ~/.ssh/${if inputs ? nixosConfig then "machine" else "me"}";
        };

        # 0 means number of cores:
        # https://github.com/git/git/blob/d15644fe0226af7ffc874572d968598564a230dd/submodule-config.c#L306-L307
        fetch.parallel = 0;
        submodules.fetchJobs = 0;

        merge.conflictstyle = "diff3";

        # https://gist.github.com/Kovrinic/ea5e7123ab5c97d451804ea222ecd78a
        #
        # make it so that we don't have to manually rewrite submodule URLs (for
        # repos that are private) to use SSH instead of HTTPS — we purposefully
        # do not set up HTTPS GitHub auth
        url."git@github.com:".insteadOf = "https://github.com/";
      }; # TODO; can also use `.includes.---.{condition,contents}`
      ignores = [
        "*.swp"
        ".nfs*"
        ".DS_Store"
      ];
      lfs.enable = true;
      signing = {
        key = (import ../../../resources/secrets/pub.nix).rahul;
        signByDefault = true;
      };
      userEmail = "rrbutani@users.noreply.github.com";
      userName = "Rahul Butani";
    };

    # TODO: gnome-terminal?

    # TODO: htop settings
    htop = {
      enable = true;

      /*
      # Beware! This file is rewritten by htop when settings are changed in the interface.
      # The parser is also very primitive, and not human-friendly.
      htop_version=3.2.1
      config_reader_min_version=3

      # fields=0 48 17 18 38 39 40 2 46 47 49 1
      # hide_kernel_threads=1
      # hide_userland_threads=0
      # shadow_other_users=0
      # show_thread_names=1
      # show_program_path=1
      # highlight_base_name=1
      # highlight_deleted_exe=1
      # highlight_megabytes=1
      # highlight_threads=1
      # highlight_changes=1
      # highlight_changes_delay_secs=5
      # find_comm_in_cmdline=1
      # strip_exe_from_cmdline=1
      # show_merged_command=0
      # header_margin=1
      # screen_tabs=1
      # detailed_cpu_time=0
      # cpu_count_from_one=1
      # show_cpu_usage=1
      # show_cpu_frequency=1
      # show_cpu_temperature=1
      # degree_fahrenheit=0
      # update_process_names=0
      # account_guest_in_cpu_meter=0
      # color_scheme=0
      # enable_mouse=1
      # delay=15
      # hide_function_bar=0
      header_layout=two_50_50
      column_meters_0=LeftCPUs Memory Swap ZFSARC ZFSCARC DiskIO NetworkIO Battery
      column_meter_modes_0=1 1 1 2 2 2 2 2
      column_meters_1=RightCPUs Tasks Systemd Tasks LoadAverage PressureStallCPUSome Uptime
      column_meter_modes_1=1 2 2 2 2 2 2
      tree_view=1
      sort_key=46
      tree_sort_key=0
      sort_direction=-1
      tree_sort_direction=1
      tree_view_always_by_pid=1
      all_branches_collapsed=0
      screen:Main=PID USER PRIORITY NICE M_VIRT M_RESIDENT M_SHARE STATE PERCENT_CPU PERCENT_MEM TIME Command
      .sort_key=PERCENT_CPU
      .tree_sort_key=PID
      .tree_view=1
      .tree_view_always_by_pid=1
      .sort_direction=-1
      .tree_sort_direction=1
      .all_branches_collapsed=0
      screen:I/O=PID USER IO_PRIORITY IO_RATE IO_READ_RATE IO_WRITE_RATE
      .sort_key=IO_RATE
      .tree_sort_key=PID
      .tree_view=0
      .tree_view_always_by_pid=0
      .sort_direction=-1
      .tree_sort_direction=1
      .all_branches_collapsed=0
      */

      settings = with config.lib.htop; ({
        fields = with config.lib.htop.fields; [
          PID USER PRIORITY NICE
          M_SIZE M_RESIDENT M_SHARE
          STATE
          PERCENT_CPU PERCENT_MEM
          TIME
          COMM
        ];

        hide_kernel_threads = 1;
        hide_userland_threads = 1;
        shadow_other_users = 1;
        show_thread_names = 1;
        show_program_path = 1;
        highlight_base_name = 1;
        highlight_deleted_exe = 1;
        highlight_megabytes = 1;
        highlight_threads = 1;
        highlight_changes = 1;
        highlight_changes_delay_secs = 5;
        find_comm_in_cmdline = 1;
        strip_exe_from_cmdline = 1;
        show_merged_command = 0;
        header_margin = 1;
        screen_tabs = 1;
        detailed_cpu_time = 0;
        cpu_count_from_one = 1;
        show_cpu_usage = 1;
        show_cpu_frequency = 1;
        show_cpu_temperature = 1;
        degree_fahrenheit = 0;
        update_process_names = 0;
        account_guest_in_cpu_meter = 0;
        color_scheme = 0;
        enable_mouse = 1;
        delay = 15;
        hide_function_bar = 0;
      } // (leftMeters [
        (bar  "LeftCPUs")
        (blank)
        (bar  "Memory")
        (bar  "Swap")
        (blank)
        (text "ZFSARC")
        (text "ZFSCARC")
        (text "DiskIO")
        (blank)
        (text "NetworkIO")
      ]) // (rightMeters [
        (bar  "RightCPUs")
        (blank)
        (text "Tasks")
        (text "Systemd")
        (blank)
        (text "LoadAverage")
        (text "PressureStallCPUSome")
        (blank)
        (text "Uptime")
        (text "Battery")
      ]) // {
        tree_view = 1;
        sort_key = 46;
        tree_sort_key = 0;
        sort_direction = 1;
        tree_sort_direction = 1;
        tree_view_always_by_pid = 1;
        all_branches_collapsed = 0;
      });
    };

    jq.enable = true;
    keychain = {
      enable = true;
      agents = ["ssh"];
      keys = [ "me" ]; # TODO
    };

    # TODO: kitty?
    # TODO: neovim?

    # TODO: bat MLIR theme
    # TODO: zbat? https://github.com/sharkdp/bat/issues/237
    # TODO: add support for bat syntaxes....

    man.enable = true;

    # TODO: wire this up?
    nix-index.enable = true;

    # TODO: exp
    nnn.enable = true;

    # TODO: pandoc

    # TODO: inputrc settings
    #  - https://www.gnu.org/software/bash/manual/html_node/Readline-Init-File.html
    #  - https://wiki.archlinux.org/title/Readline
    readline = {
      enable = true;
      bindings = {
        "\\e[A" = "history-search-backward";
        "\\e[B" = "history-search-forward";
      };
      extraConfig = ''
        set colored-stats On
        set completion-ignore-case On
        set completion-prefix-display-length 10
        set mark-symlinked-directories On
        set show-all-if-ambiguous On
        set show-all-if-unmodified On
        set visible-stats On
      '';
    };

    # TODO: configure rofi
    rofi.enable = true;

    # TODO: skim

    # TODO: .ssh
    ssh = {
      enable = true;
      compression = true;
      controlMaster = "auto";
      # extraConfiguration = ""; # TODO
      # matchBlocks = ""; # TODO
    };

    # TODO: configure
    starship.enable = true;
    starship.settings = {};

    # TODO: wezterm?

    # TODO: zoxide?
    # TODO: zsh?
  };

  home.extraOutputsToInstall = [
    "info"
    "man" # TODO: debug info?
  ];

  # TODO: probably spin this off, tie to `nix-locate`'s package..
  # TODO: reference $XDG_HOME_DIR somehow?
  #   - https://github.com/bennofs/nix-index/blob/e7c66ba52fcfba6bfe51adb5400c29a9622664a2/src/bin/nix-index.rs#L307
  # home.file.".cache/nix-index/files".source = nix-index-database.legacyPackages.${system}.database;
  programs.nix-index-database.comma.enable = true;
  # TODO: update ^ to support aarch64-darwin, when we get around to it..

}
