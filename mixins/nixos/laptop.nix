{ lib, config, ... }:

{
  imports = [ ./common.nix ];

  config = {
    # TODO: wayland?
    services.libinput = {
      enable = true;
      mouse = {
        naturalScrolling = true;
      };
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        tappingDragLock = true;
      };
    };

    rrbutani.gsettings = lib.mkIf (config.services.xserver.desktopManager.gnome.enable) {
        org.gnome.desktop.peripherals.touchpad = {
          speed = 0.35;
          tap-to-click = true;
          two-finger-scrolling-enabled = true;
        };

        org.gnome.settings-daemon.plugins.power = {
          # Sleep after 20 minutes of inactivity on battery power.
          sleep-inactive-battery-type = "suspend";
          sleep-inactive-battery-timeout = 1200;
        };

        org.gnome.desktop.interface.show-battery-percentage = true;
    };
  };
}
