{ lib, util, pkgs, ... }: let
  gnome = util.to-gnome-settings { inherit lib; };

  # You can dump these with `dconf dump /`.
  #
  # As you're making change in the GUI you can observe them with `dconf watch /`
  #
  # See: https://askubuntu.com/questions/522833/how-to-dump-all-dconf-gsettings-so-that-i-can-compare-them-between-two-different
  gsettings = {
    org.gnome = {
      desktop = {
        background = {
          color-shading-type = "solid";
          picture-options = "zoom";
          picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
          picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-d.svg";
          primary-color = "#3465a4";
          secondary-color = "#000000";
        };

        interface = {
          color-scheme = "prefer-dark";
          show-battery-percentage = true;
        };

        peripherals.touchpad = {
          speed = 0.027778;
          tap-to-click = true;
          two-finger-scrolling-enabled = true;
        };

        screensaver = {
          color-shading-type = "solid";
          lock-delay = gnome.mkUint32 0;
          picture-options = "zoom";
          picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/blobs-l.svg";
          primary-color = "#3465a4";
          secondary-color = "#000000";
        };

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
  ];
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

  services.xserver.desktopManager.gnome = {
    enable = true;

    # extraGSettingsOverrides = gsettings;
  };

  rrbutani.gsettings = gsettings;
}
