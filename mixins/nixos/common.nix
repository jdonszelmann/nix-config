{ configName, pkgs, lib, ... }: let
  iosevka-mono = pkgs.callPackage ../../resources/iosevka-mono.nix {};

  # TODO: spin off into resources/keymap.nix?
  xkbOptions = [
    "terminate:ctrl_alt_bksp"
    "caps:ctrl_modifier"
    "shift:both_capslock"
    "compose:ralt"
  ];
in {

  imports = [
    # <work.nix>
  ];

  # TODO: sys env: CCACHE DIR env var + nix sandbox exemption in a ccache mixin

  system.stateVersion = "22.11";

  networking.hostName = lib.mkDefault configName;

  # Use `networkmanager` instead of `wpa_supplicant`:
  networking.networkmanager.enable = true;

  # Timezone; see: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  time.timeZone = lib.mkDefault "America/Los_Angeles";

  # Locale:
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "iosevka-mono";
    packages = [ iosevka-mono ];
    # colors = # TODO: nord;
    useXkbConfig = true;
  };

  # fonts:
  fonts.packages = [ iosevka-mono ];

  # Keymap:
  # for gnome at least, this seems to work with wayland, not sure about others
  #  - https://unix.stackexchange.com/questions/292868/how-to-customise-keyboard-mappings-with-wayland
  #  - https://discourse.nixos.org/t/setting-caps-lock-as-ctrl-not-working/11952/8
  #  - https://discourse.nixos.org/t/problem-with-xkboptions-it-doesnt-seem-to-take-effect/5269/11
  # `gsettings get org.gnome.desktop.input-sources xkb-options "['a','x']"` seems to do it, for manual setting
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.options = builtins.concatStringsSep "," xkbOptions;

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

  # TODO: spin off into a proxies.nix mixin? not sure
  security.sudo.extraConfig = ''
    # Keep proxy env vars:
    Defaults:root,%wheel env_keep+=http_proxy
    Defaults:root,%wheel env_keep+=https_proxy
    Defaults:root,%wheel env_keep+=socks_proxy
    Defaults:root,%wheel env_keep+=no_proxy
    Defaults:root,%wheel env_keep+=HTTP_PROXY
    Defaults:root,%wheel env_keep+=HTTPS_PROXY
    Defaults:root,%wheel env_keep+=SOCKS_PROXY
    Defaults:root,%wheel env_keep+=NO_PROXY
  '';

  # TODO: spin off? idk
  programs.nix-ld.enable = true;

  # TODO: spin off into its own mixin; this isn't specific to nixos
  nix = {
    settings = {
      # Enable flakes!
      extra-experimental-features = [ "nix-command" "flakes" ];
      sandbox = true;

      # Inherit this flake's extra substituters.
      inherit ((import ../../flake.nix).nixConfig)
        # extra-substituters
        extra-trusted-public-keys;

      # Include `root` in the trusted users (this is the default but it gets
      # overwritten instead of appended to if we set `trusted-users` anywhere):
      trusted-users = [ "root" ];
    };
  };

  # TODO: spin off with the above, gate on this being enabled.
  # Have trusted nix settings persist.
  rrbutani.impermanence.extra.dirs = [
    "/root/.local/share/nix"
  ];

  # https://github.com/NixOS/nixpkgs/issues/33282
  # Let users manage this themselves with the home-manager module:
  # https://github.com/nix-community/home-manager/blob/master/modules/misc/xdg-user-dirs.nix
  environment.etc."xdg/user-dirs.defaults".text = "";

  environment.systemPackages = with pkgs; [
    bat ripgrep unzip file hexyl lsof tree

    htop # TODO: config to show CPU temps and freq
    i7z

    # dig? nslookup? nano?
  ];
}
