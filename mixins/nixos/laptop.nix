{ ... }:

{
  imports = [ ./common.nix ];

  # TODO: wayland?
  services.xserver.libinput = {
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
}
