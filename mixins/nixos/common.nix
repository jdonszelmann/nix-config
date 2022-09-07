{ configName, pkgs, lib, ... }: let
  iosevka-mono = pkgs.callPackage ../../resources/iosevka-mono.nix {};

  # TODO: spin off into common/keymap.nix?
  xkbOptions = [
    "terminate:ctrl_alt_bksp"
    "caps:ctrl_modifier"
    "shift:both_capslock"
    "compose:ralt"
  ];
in {
  system.stateVersion = "22.11";

  networking.hostName = lib.mkDefault configName;

  # Use `networkmanager` instead of `wpa_supplicant`:
  networking.networkmanager.enable = true;

  # Timezeon; see: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  time.timeZone = lib.mkDefault "America/Rainy_River";

  # Locale:
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "iosevka-mono";
    packages = [ iosevka-mono ];
    # colors = # TODO: nord;
    useXkbConfig = true;
  };

  # Keymap:
  # TODO: this probably doesn't work with wayland?
  # https://unix.stackexchange.com/questions/292868/how-to-customise-keyboard-mappings-with-wayland
  # https://discourse.nixos.org/t/setting-caps-lock-as-ctrl-not-working/11952/8
  # https://discourse.nixos.org/t/problem-with-xkboptions-it-doesnt-seem-to-take-effect/5269/11
  # `gsettings get org.gnome.desktop.input-sources xkb-options "['a','x']"` seems to do it
  # perhaps: `services.xserver.desktopManager.gnome.extraGSettingsOverrides`?
  services.xserver.layout = "us";
  services.xserver.xkbOptions = builtins.concatStringsSep "," xkbOptions;

  # Enable CUPS:
  services.printing.enable = true;

  # Enable sound:
  #
  # See: https://nixos.wiki/wiki/PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  hardware.pulseaudio.enable = false; # conflicts with pipewire

  # TODO: nixPath tie to /run/current-system/nixpkgs?
  # nixpkgs.allowUnfree

  users.mutableUsers = false;
}
