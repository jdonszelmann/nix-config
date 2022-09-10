{
  lib,
  util,
  pkgs,
  ...
}: let
  gnome = util.to-gnome-settings {inherit lib;};

  gsettings = /* gnome.toGnomeSettings */ {
      org.gnome = {
        # Geary.migrated-config = true;

        # control-center = {
        #   last-panel = "keyboard";
        #   window-state = mkTuple [980 640 false];
        # };

        desktop = {
          #   app-folders = {
          #     folder-children = ["Utilities" "YaST"];
          #     folders = {
          #       Utilities = {
          #         apps = [
          #           "gnome-abrt.desktop"
          #           "gnome-system-log.desktop"
          #           "nm-connection-editor.desktop"
          #           "org.gnome.baobab.desktop"
          #           "org.gnome.Connections.desktop"
          #           "org.gnome.DejaDup.desktop"
          #           "org.gnome.Dictionary.desktop"
          #           "org.gnome.DiskUtility.desktop"
          #           "org.gnome.eog.desktop"
          #           "org.gnome.Evince.desktop"
          #           "org.gnome.FileRoller.desktop"
          #           "org.gnome.fonts.desktop"
          #           "org.gnome.seahorse.Application.desktop"
          #           "org.gnome.tweaks.desktop"
          #           "org.gnome.Usage.desktop"
          #           "vinagre.desktop"
          #         ];
          #         categories = ["X-GNOME-Utilities"];
          #         name = "X-GNOME-Utilities.directory";
          #         translate = true;
          #       };

          #       YaST = {
          #         categories = ["X-SuSE-YaST"];
          #         name = "suse-yast.directory";
          #         translate = true;
          #       };
          #     };
          #   };

          background = {
            color-shading-type = "solid";
            picture-options = "zoom";
            # picture-uri = /run/current-system/sw/share/backgrounds/gnome/blobs-l.svg;
            picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
            # picture-uri-dark = /run/current-system/sw/share/backgrounds/gnome/blobs-d.svg;
            picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-d.svg";
            primary-color = "#3465a4";
            secondary-color = "#000000";
          };

          # input-sources = {
          #   sources = [
          #     (mkTuple [ "xkb" "us" ])
          #   ];
          #   xkb-options = [
          #     "terminate:ctrl_alt_bksp"
          #     "caps:ctrl_modifier"
          #     "shift:both_capslock"
          #     "compose:ralt"
          #   ];
          # };

          interface = {
            color-scheme = "prefer-dark";
            show-battery-percentage = true;
          };

          # notifications.application-children = [ "org-gnome-console" "firefox" ];
          # notifications.application = {
          #   org-gnome-console.application-id = "org.gnome.Console.desktop";
          #   firefox.application-id = "firefox.desktop";
          # };

          peripherals.touchpad = {
            speed = 0.027778;
            tap-to-click = true;
            two-finger-scrolling-enabled = true;
          };

          # privacy = {
          #   old-files-age = mkUint32 30;
          #   recent-files-max-age = -1;
          # };

          screensaver = {
            color-shading-type = "solid";
            lock-delay = gnome.mkUint32 0;
            picture-options = "zoom";
            picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
            primary-color = "#3465a4";
            secondary-color = "#000000";
          };

          # search-providers.sort-order = [
          #   "org.gnome.Contacts.desktop"
          #   "org.gnome.Documents.desktop"
          #   "org.gnome.Nautilus.desktop"
          # ];

          session.idle-delay = gnome.mkUint32 240;

          sound = {
            event-sounds = true;
            theme-name = "__custom";
          };

          wm.keybindings = {
            move-to-workspace-left = ["<Alt><Super>Left"];
            move-to-workspace-right = ["<Alt><Super>Right"];
            switch-group = ["<Super>grave"];
            switch-group-backward = ["<Shift><Super>grave"];
            switch-to-workspace-left = ["<Super>Left"];
            switch-to-workspace-right = ["<Super>Right"];
            toggle-fullscreen = ["<Shift><Super>f"];
          };
        };

        # evolution-data-server = {
        #   migrated = true;
        #   network-monitor-gio-name = "";
        # };

        mutter = {
          attach-modal-dialogs = true;
          dynamic-workspaces = true;
          edge-tiling = true;
          focus-change-on-pointer-rest = true;
          workspaces-only-on-primary = false;

          keybindings = {
            toggle-tiled-left = ["<Control><Super>Left"];
            toggle-tiled-right = ["<Control><Super>Right"];
          };
        };

        settings-daemon.plugins = {
          color = {
            night-light-enabled = true;
            night-light-temperature = gnome.mkUint32 2845;
          };

          media-keys = {
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/user-defined/custom0/"
            ];
            next = ["0x100811be"];
            play = ["Favorites"];
            previous = ["0x100811bd"];
            www = ["<Super>b"];

            user-defined = {
              custom0 = {
                binding = "<Super>t";
                command = "kgx";
                name = "Open Terminal";
              };
            };
          };

          power.power-button-action = "suspend";
        };

        shell = {
          welcome-dialog-last-shown-version = "42.4";

          app-switcher.current-workspace-only = true;

          keybindings = {
            show-screen-recording-ui = ["<Shift><Super>r"];
            show-screenshot-ui = ["<Shift><Super>s"];
          };

          # TODO: move all of these elsewhere (home-manager config? top-level?)
          favorite-apps = [
            "firefox.desktop"
            "org.gnome.Calendar.desktop"
            "org.gnome.Nautilus.desktop"
            "org.gnome.Geary.desktop"
            "spotify.desktop"
            "teams.desktop"
            "org.gnome.Photos.desktop"
            "org.gnome.Console.desktop"
            "code.desktop"
            "org.gnome.Settings.desktop"
            # Move out!!!
          ];

          # world-clocks.locations = mkLocation [];
        };
      };

      # system.proxy.mode = "none";
    };

    mkCompiledDconf = conf: let
      str = gnome.toGnomeSettings conf;
      file = pkgs.writeTextDir "dconf/db" str;

      compile = dir: pkgs.runCommand "dconf-db" { } ''
        ${pkgs.dconf}/bin/dconf compile $out ${dir}
      '';

      compiled = compile "${file}/dconf";
    in
      "file-db:${compiled}";
in {
  services.xserver.desktopManager.gnome = {
    enable = true;
    # You can dump these with `dconf dump /`.
    #
    # As you're making change in the GUI you can observe them with `dconf watch /`
    #
    # See: https://askubuntu.com/questions/522833/how-to-dump-all-dconf-gsettings-so-that-i-can-compare-them-between-two-different
    extraGSettingsOverrides = gsettings;
  };

}
