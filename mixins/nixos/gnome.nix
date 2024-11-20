{ lib, util, pkgs, ... }: let
  gnome = util.to-gnome-settings;

  # You can dump these with `dconf dump /`.
  #
  # As you're making change in the GUI you can observe them with `dconf watch /`
  #
  # See: https://askubuntu.com/questions/522833/how-to-dump-all-dconf-gsettings-so-that-i-can-compare-them-between-two-different
  gsettings = {
    org.gtk.settings.file-chooser.clock-format = "12h";
    org.gnome = {
      desktop = {
        background = {
          color-shading-type = "solid";
          picture-options = "zoom";
          # picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
          # picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-d.svg";
          picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-l.jpg";
          picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-d.jpg";
          primary-color = "#3071AE";
          secondary-color = "#000000";
        };

        calendar.show-weekdate = true;

        interface = {
          color-scheme = "prefer-dark";
          clock-format = "12h";
        };

        peripherals.mouse.natural-scroll = true;

        screensaver = {
          color-shading-type = "solid";
          lock-delay = gnome.mkUint32 0;
          picture-options = "zoom";
          # picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
          # picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-d.webp";
          picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-l.jpg";
          primary-color = "#3071AE";
          secondary-color = "#000000";
        };

        # 100 minutes of inactivity before turning the display off.
        session.idle-delay = gnome.mkUint32 6000;
        # TODO: set to 10, override in other configs..

        sound = {
          event-sounds = true;
          theme-name = "__custom";
        };

        wm.keybindings = {
          # alt to move a window across workspaces:
          move-to-workspace-left = ["<Alt><Super>Left"];
          move-to-workspace-right = ["<Alt><Super>Right"];

          move-to-workspace-last = ["<Alt><Super>0"];
          move-to-workspace-1 = ["<Alt><Super>1"];
          move-to-workspace-2 = ["<Alt><Super>2"];
          move-to-workspace-3 = ["<Alt><Super>3"];
          move-to-workspace-4 = ["<Alt><Super>4"];
          move-to-workspace-5 = ["<Alt><Super>5"];
          move-to-workspace-6 = ["<Alt><Super>6"];
          move-to-workspace-7 = ["<Alt><Super>7"];
          move-to-workspace-8 = ["<Alt><Super>8"];
          move-to-workspace-9 = ["<Alt><Super>9"];

          # TODO: add move display keybinds (even though we're using the
          # defaults): shift for all

          switch-to-workspace-last = ["<Super>0"];
          switch-to-workspace-1 = ["<Super>1"];
          switch-to-workspace-2 = ["<Super>2"];
          switch-to-workspace-3 = ["<Super>3"];
          switch-to-workspace-4 = ["<Super>4"];
          switch-to-workspace-5 = ["<Super>5"];
          switch-to-workspace-6 = ["<Super>6"];
          switch-to-workspace-7 = ["<Super>7"];
          switch-to-workspace-8 = ["<Super>8"];
          switch-to-workspace-9 = ["<Super>9"];

          # TODO: add type annotations (i.e. `@as []`) so this can be empty?
          switch-to-application-1 = ["<Alt><Super><Shift><Ctrl>1"];
          switch-to-application-2 = ["<Alt><Super><Shift><Ctrl>2"];
          switch-to-application-3 = ["<Alt><Super><Shift><Ctrl>3"];
          switch-to-application-4 = ["<Alt><Super><Shift><Ctrl>4"];
          switch-to-application-5 = ["<Alt><Super><Shift><Ctrl>5"];
          switch-to-application-6 = ["<Alt><Super><Shift><Ctrl>6"];
          switch-to-application-7 = ["<Alt><Super><Shift><Ctrl>7"];
          switch-to-application-8 = ["<Alt><Super><Shift><Ctrl>8"];
          switch-to-application-9 = ["<Alt><Super><Shift><Ctrl>9"];

          switch-to-workspace-left = ["<Super>Left"];
          switch-to-workspace-right = ["<Super>Right"];

          switch-group = ["<Super>grave"];
          switch-group-backward = ["<Shift><Super>grave"];
          toggle-fullscreen = ["<Shift><Super>f"];

          show-desktop = ["<Shift><Super>h"];
        };
      };

      mutter = {
        attach-modal-dialogs = true;
        dynamic-workspaces = true;
        edge-tiling = true;
        focus-change-on-pointer-rest = true;
        workspaces-only-on-primary = false;

        keybindings = {
          toggle-tiled-left = ["<Control><Super>Left"];
          toggle-tiled-right = ["<Control><Super>Right"];

          # This removes the `Super + P` binding.
          #
          # Everytime I come back to gnome after using macOS for a bit, I'll hit
          # `cmd + p` instead of `ctrl + p` to open the command palette in
          # VSCode which triggers this keybind.
          #
          # Something about mutter and my display config is broken; if I trigger
          # this "switch monitor" thing I cannot set my external monitor back to
          # being the primary without restarting mutter which is: incredibly
          # annoying and wastes lots of time. >.>
          switch-monitor = ["XF86Display"];
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

        power = {
          power-button-action = "suspend";

          # Don't auto-suspend when plugged in.
          sleep-inactive-ac-timeout = 7200;
          sleep-inactive-ac-type = "nothing";
        };
      };

      shell = {
        welcome-dialog-last-shown-version = "42.4";

        app-switcher.current-workspace-only = true;

        keybindings = {
          show-screen-recording-ui = ["<Shift><Super>r"];
          show-screenshot-ui = ["<Shift><Super>s" "Print"];
        };

        # TODO: move all of these elsewhere (home-manager config? top-level?)
        favorite-apps = [
          "firefox.desktop"
          "org.gnome.Calendar.desktop"
          "org.gnome.Nautilus.desktop"
          "org.gnome.Geary.desktop"
          "spotify.desktop"
          # "teams.desktop" # !!! update
          "teams-for-linux.desktop"
          "org.gnome.Photos.desktop"
          "org.gnome.Console.desktop"
          "code.desktop"
          "org.gnome.Settings.desktop"
          # Move out!!!
        ];

        # weather.locations = [];
        # also: /org/gnome/Weather/locations
      };
    };
  };


in {
  imports = [
    ../../modules/nixos/gsettings.nix
  ];

  # TODO: gate on this being enabled, don't tie to this user..
  #
  # See: https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/95
  home-manager.users.rahul.rrbutani.impermanence.extra.files = [
    ".local/share/sounds/" # TODO: configure this in nix, too?
    # It's just a directory with:
    #  __custom/index.theme:
    # ```
    # [Sound Theme]
    # Name=Custom
    # Inherits=__custom
    # Directories=.
    # ```
    # and
    # `bell-terminal.ogg` and `bell-window-system.ogg` that are symlinks to `gnome-control-center/share/sounds/default/allerts/glass.ogg`

    ".config/monitors.xml" # TODO: configure this in nix too?
    # https://wiki.gnome.org/Initiatives/Wayland/Gaps/DisplayConfig
    # https://github.com/jadahl/gnome-monitor-config/blob/master/src/org.gnome.Mutter.DisplayConfig.xml
  ];

  services.xserver.desktopManager.gnome = {
    enable = true;

    # extraGSettingsOverrides = gsettings;
  };

  rrbutani.gsettings = gsettings;
}
