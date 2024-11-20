inputs@{ nixos-hardware, ragenix, ... }:

{
  system = "x86_64-linux";

  modules = [
    # Hardware config:
    ./hardware-configuration.nix

    # Boot/Encryption:
    ./boot-and-encryption.nix

    # Filesystems, ZFS stuff:
    ./filesystems.nix
    ./zfs.nix

    # Common machine configuration.
    ../../mixins/nixos/laptop.nix

    # Fingerprint Auth:
    ../../mixins/nixos/fprint.nix

    # Set up agenix:
    ragenix.nixosModules.age
    ({ config, configName, ... }: {
      age = {
        secretsDir = "/run/secrets";
        identityPaths = [
          # These needs to go first because of this bug:
          # https://github.com/ryantm/agenix/issues/116
          # https://github.com/str4d/rage/issues/294
          #
          # `rage` essentially doesn't seem to be tolerant of paths that don't exist.
          "/persistent/etc/secrets/${configName}"

          # This path is acceptable when running `nixos-rebuild switch` and restarting
          # things in userspace but this isn't acceptable for the secrets that agenix
          # decrypts at the start of stage2-init because the `/etc/` symlinks don't
          # seem to be created by then.
          #
          # So, for now, we just reference the path above.
          #
          # TODO: perhaps we should make this symlink in stage1, post ZFS mount?
          # "/etc/secrets/${configName}"

          # config.age.secrets.machine-key.path # See above! rage is not tolerant of paths that don't exist and this path doesn't exist until agenix creates it.
        ]; # ++ (builtins.map (p: p.path) config.services.openssh.hostKeys);

        secrets.machine-key = {
          file = ../../resources/secrets/cayahuanca.age;
          mode = "600";
          owner = config.users.users.rahul.name;
        };
      };
    })

    # Host SSH key:
    ({ config, configName, ... }: {
      services.openssh.hostKeys = [
        {
          path = config.age.secrets.machine-key.path;
          type = "ed25519";
        }
      ];
    })

    # Monitor, wayland:
    #
    # https://davejansen.com/add-custom-resolution-and-refresh-rate-when-using-wayland-gnome/
    {
      boot.kernelParams = [
        # This: does not work :-(.
        # "video=DP-2:3440x1440@60"
        # "video=DP-2:3440x1440@100"
      ];
      # Maybe we should flash EDID instead? The above is tied to the port, not the monitor
      #  - https://lists.ubuntu.com/archives/kernel-team/2012-March/018805.html
      #  - https://wiki.debian.org/RepairEDID
    }

    # Monitor, X:
    # https://askubuntu.com/questions/377937/how-do-i-set-a-custom-resolution
    {
      services.xserver.xrandrHeads = [
        "eDP-1" # laptop
        {
          output = "DP-2"; # external, type-C port
          primary = true;
          monitorConfig = ''
            # 1920x1080 99.90 Hz (CVT) hsync: 114.58 kHz; pclk: 302.50 MHz
            Modeline "1920x1080_100.00"  302.50  1920 2072 2280 2640  1080 1083 1088 1147 -hsync +vsync

            # 3440x1440 59.94 Hz (CVT) hsync: 89.48 kHz; pclk: 419.50 MHz
            Modeline "3440x1440_60.00"  419.50  3440 3696 4064 4688  1440 1443 1453 1493 -hsync +vsync
            # 3440x1440 65.95 Hz (CVT) hsync: 98.80 kHz; pclk: 464.75 MHz
            Modeline "3440x1440_66.00"  464.75  3440 3704 4072 4704  1440 1443 1453 1498 -hsync +vsync
            # 3440x1440 99.99 Hz (CVT) hsync: 152.68 kHz; pclk: 728.00 MHz
            Modeline "3440x1440_100.00"  728.00  3440 3728 4104 4768  1440 1443 1453 1527 -hsync +vsync

            Option "PreferredMode" "3440x1440_60.0"
          '';
        }
      ];
    }

    # TODO: vscode, system wide, fonts (mono iosevka)

    # TODO: machine password
    # TODO: user password (+ override)

    # TODO: work config flake thing
    #  - vpn
    #  - teams
    #  - proxies
    #  - email

    # TODO: vscode
    #  - default theme
    #  - basic keybinds
    #  - github login?

    # TODO: git config (+ssh key for signing)
    #    - !!! age filter: https://seankhliao.com/blog/12020-09-24-gitattributes-age-encrypt/
    #                      https://github.com/lovesegfault/nix-config/blob/60eabb30fa2f4b435e61cd1790b8ffb7fd789422/users/bemeurer/core/git.nix#L18
    # TODO: ssh config, keys

    # TODO: ssh host key
    # TODO: add this repo to the flake registry in the machine
    # TODO: add this repo's extra caches to the user level nix config

    # TODO: systemd-boot + secure-boot
    #       (really, GRUB + secure-boot..)

    # TODO: zram swap
    #
    # TODO: primary monitor: https://www.baeldung.com/linux/primary-monitor-x-wayland#2-changing-the-primary-monitor-in-gnome

    # Display Manager, Desktop Manager, Window Manager, etc.
    ({ config, pkgs, ... }: {
      # Don't suspend on lid close.
      # services.logind.lidSwitch = "ignore";

      services.displayManager = {
        enable = true; # TODO: why isn't this implied?

        autoLogin = { user = config.users.users.rahul.name; enable = true; };
        defaultSession = "gnome";
      };

      # the name is misleading?
      services.xserver = {
        displayManager = {
          gdm = {
            enable = true;

            # Problems with wayland:
            #  - auto login doesn't work (minor)
            #  - can't override the display refresh rate, stuck at 30Hz
            #  - copy/paste + link opening starts to fail globally after some time (`code` too)
            #  - on the login screen, it unconditionally waits for fingerprint input (blocks); annoying when the lid is closed
            #
            # On the other hand libinput gestures only work on wayland
            #
            # So: disabling wayland for now (refresh rate is a dealbreaker) :/
            # update: it's fine actually
            #
            # https://arewewaylandyet.com/
            wayland = true;
          };
        };

        # desktopManager = {
        # pantheon.enable = true; # TODO
        # gnome.enable = true;
        # };

        # windowManager  = ... # TODO
      };

      environment.systemPackages = [
        pkgs.wl-clipboard # TODO: gate on wayland?
      ];

      imports = [
        ../../mixins/nixos/gnome.nix
      ];
    })

    # Users
    ../../mixins/common/users/rahul.nix
    ../../mixins/home-manager/users
    ({lib, ...}: {
      # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      #   "vscode-extension-ms-vscode-remote-remote-ssh"
      # ];
      nixpkgs.config.allowUnfree = true;
    })

    # Passsword, root:
    ({config, ...}: {
      # age.secrets.root-pass.file = ../../resources/secrets/r-pass.age;
      # users.users.root.passwordFile = config.age.secrets.root-pass.path;
      # users.users.root.password = "hello";
      users.users.root.hashedPasswordFile = config.users.users.rahul.hashedPasswordFile;


      rrbutani.users.rahul.root = true;
      rrbutani.users.rahul.ageEncryptedPasswordFile = ../../resources/secrets/r-pass.age;
    })

    # SSH:
    {
      services.openssh.enable = true;
      users.users.rahul.openssh.authorizedKeys.keys = [
        (import ../../resources/secrets/pub.nix).rahul
      ];
    }

    # User keys:
    # TODO: we'd like to have home-manager handle this but there isn't yet a
    # good home-manager (r)agenix solution.
    ({ config, configName, lib, pkgs, ragenix, system, ... }: {
      age.secrets.r-sshKey = {
        file = ../../resources/secrets/r-ssh.age;
        mode = "600";
        owner = config.users.users.rahul.name;
      };
      # This is not at all secret; we just do this so that the `realpath`
      # of the public key is in the same dir as the private key above.
      #
      # This is required to get `keychain` to stop complaining about
      # not being able to find the public key.
      #
      # TODO: find an appropriate place to stick this...

      # (This doesn't run all the times the agenix stuff does which is annoying..)
      # boot.postBootCommands = let
      #   pubKey = (import ../../resources/secrets/pub.nix).rahul;
      #   dir = config.age.secretsDir;
      # in lib.mkAfter ''
      #   pushd $(realpath ${dir})
      #   echo "${pubKey}" > r-sshKey.pub
      #   popd
      # '';

      system.activationScripts.agenixInstall.text = let
        pubKey = (import ../../resources/secrets/pub.nix).rahul;
        dir = config.age.secretsDir;
      in lib.mkAfter ''
        pushd $(realpath ${dir})
        echo "${pubKey}" > r-sshKey.pub
        popd
      '';

      home-manager.users.rahul.home.file = let
        hmConfig = config.home-manager.users.rahul;
        inherit (hmConfig.lib.file) mkOutOfStoreSymlink;
      in {
        ".ssh/id_rsa".source = mkOutOfStoreSymlink config.age.secrets.r-sshKey.path;
        ".ssh/me".source = mkOutOfStoreSymlink config.age.secrets.r-sshKey.path;
        ".ssh/me.pub".source = # mkOutOfStoreSymlink (config.age.secrets.r-sshKey.path + ".pub");
          pkgs.writeTextFile
          {
            name = "me.pub";
            text = (import ../../resources/secrets/pub.nix).rahul;
          };
        ".ssh/machine".source = mkOutOfStoreSymlink config.age.secrets.machine-key.path;
      };
    })

    # Set up impermanence:
    #
    # note: /home is handled by selectively symlinking things over from /persistent
    ../../modules/nixos/impermanence.nix
    {
      rrbutani.impermanence = {
        persistentStorageLocation = "/persistent";
        resetCommand = ''
          echo "Rolling back root to the blank snapshot..."
          zfs rollback -r x/ephemeral/root@tabula-rasa
        '';
        # TODO: keep around the last root's contents as a snapshot?
      };

      home-manager.users.rahul.rrbutani.impermanence.extra = {
        dirs = [];
      };

      home-manager.users.rahul.programs.bash.shellAliases = {
        root-diff =
          "sudo zfs diff x/ephemeral/root@tabula-rasa | grep -v \\\.cache | grep -v Cache | grep -v IndexedDB";
        compress-ratio =
          "zfs get all x | grep comp";
        dedupe-ratio =
          "zpool list";
      };
    }
    # hmmmm: https://github.com/nix-community/impermanence/issues/18 (TODO)

    ({ config, configName, ... }: let
      # configPath = config.users.users.rahul.home + "/dev/config";
      configPath = "/persistent" + config.users.users.rahul.home + "/dev/config";

      registry = {
        local-config = {
          from = {
            id = "local-config";
            type = "indirect";
          };
          to = {
            path = "${configPath}/main";
            type = "path";
          };
        };

        # Override the default `nixpkgs` registry entry with the `nixpkgs`
        # used by this flake!
        nixpkgs.flake = inputs.nixpkgs;
      };
    in {
      home-manager.users.rahul.programs.bash.shellAliases = {
        update =
          # "sudo nixos-rebuild --flake local-config# switch";
          "sudo nixos-rebuild --flake local-config#${configName} switch"; # TODO: alias the config so we don't have to do this?
        edit = "code $(realpath ${configPath})";
        dev = "cd $(realpath ${config.users.users.rahul.home}/dev/)";
        conf = "cd $(realpath ${config.users.users.rahul.home}/dev/config/main)";
      };

      home-manager.users.rahul.nix.registry = registry;
      nix.registry = registry;
      # TODO: automate adding the checkout of this repo to the
      # local flake registry?
      # `nix registry add local-config path:$(realpath ...)`
      #   - can maybe just assume it's checked out to `dev`
      # (update: done)

      # override the `nixpkgs` nix-channel with the nixpkgs used by this flake:
      home-manager.users.rahul.home.sessionVariables = {
        NIX_PATH = "nixpkgs=${inputs.nixpkgs.outPath}";
      };
    })

    # misc:
    ({ lib, ... }: {
      nix.settings = {
        extra-sandbox-paths = [
          "/nix/var/cache"
        ];
        builders-use-substitutes = true;

        # # https://mynixos.com/nixpkgs/option/nix.settings.sandbox
        # # https://zimbatm.com/notes/nix-packaging-the-heretic-way
        # sandbox = lib.mkForce "relaxed";

        connect-timeout = 2;
        fallback = true;
      };
    })

    # touch screen support for firefox (with X):
    ({
      environment.sessionVariables = {
        MOZ_USE_XINPUT2 = "1";
      };
    })

    ({
      virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
      };
      users.users.rahul.extraGroups = [ "docker" ];
    })

    # Custom nix fork (TODO):
    #   - lazy trees: https://github.com/NixOS/nix/pull/6530
    #   - multi-threaded evaluator: https://github.com/NixOS/nix/pull/10938
    #   - flake schemas: https://github.com/NixOS/nix/pull/8892
    #   - git fetcher tweaks (incremental w/submodules): https://github.com/rrbutani/nix/tree/feat/git-fetchers-tweaks
    #     + actually... this is Obviated by the git fetcher rewrite in nix 2.20+
    #       * see: https://gist.github.com/rrbutani/7776583cf474a32b815ea26c0e7ddce1
    ({ pkgs, lib, ... }: {
      environment.systemPackages = let
        nixFork = let
          # flake = builtins.getFlake {
          #   url = "github:rrbutani/nix";
          #   ref = "dist/lazy-trees-with-git-fetcher-tweaks";
          #   rev = "ff4b55d525865d7987919ffc177a119d93213cc1";
          # };
          # flake = builtins.getFlake "github:rrbutani/nix/dist/lazy-trees-with-git-fetcher-tweaks?rev=ff4b55d525865d7987919ffc177a119d93213cc1";
          # flake = builtins.getFlake "github:rrbutani/nix?rev=ff4b55d525865d7987919ffc177a119d93213cc1";
          flake = builtins.getFlake "github:NixOS/nix?rev=f1deb42176cadfb412eb6f92315e6aeef7f2ad75"; # 2.23.3
        in flake.packages.${pkgs.stdenv.hostPlatform.system}.nix;

        nix-custom = pkgs.runCommandNoCC "nix-exp" {} ''
          mkdir -p $out/bin
          ln -s ${lib.getExe nixFork} $out/bin/$name
        '';
      in [ nix-custom ];
    })

    ({ pkgs, ... }: {
      environment.systemPackages = [ pkgs.intel-gpu-tools.out ]; # for `intel_gpu_top`
    })

    {
      programs.gnome-terminal.enable = true;
    }

    ({ pkgs, ... }: {
      services.udev.packages = [ pkgs.picotool ];
      users.groups.plugdev = {};
      users.users.rahul.extraGroups = [ "plugdev" ];

      services.udev.extraRules = ''
        SUBSYSTEM=="usb", \
          ATTRS{idVendor}=="2e8a", \
          ATTRS{idProduct}=="000c", \
          TAG+="uaccess" \
          MODE="660", \
          GROUP="plugdev"
      '';
    })
  ];

  # TODO: compose key:
  # https://gist.github.com/m93a/187539552593dd4ed8b122167c09384c

}

# TODO: persist .cache/nix/{fetcher-cache-v1.sqlite{,-journal},eval-cache-v4,binary-cache-v6.sqlite{,-journal},flake-registry.json}

# TODO: drop bindfs for impermanence? https://github.com/nix-community/impermanence/issues/42
