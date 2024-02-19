# There is a `services.xserver.desktopManager.gnome.extraGSettingsOverrides`
# option but today this has a couple of "problems":
#  - it accepts strings, not nix attrsets
#  - these settings don't actually take:
#    + https://github.com/NixOS/nixpkgs/issues/66554
#    + https://github.com/NixOS/nixpkgs/issues/54150
#
# This PR fixes both of these issues (the latter by creating a user dconf
# config): https://github.com/NixOS/nixpkgs/pull/189099
#
# This modules is kind of a bad approximation of the fixes in that PR.
#
# Because the above PR changes `lib`, swapping it's `dconf` module into our
# config (using `disabledModules` to disable the regular `dconf` module) is not
# so straightforward.
#
# Instead, this module just writes out the user config file the PR above does,
# without any of the careful handling around multiple users or defaults.
#
# It's not pretty but it's an effective stopgap solution.

{ lib, util, pkgs, config, ... }: let
  gnome = util.to-gnome-settings;

  mkCompiledDconf = conf: let
    str = gnome.toGnomeSettings conf;
    file = pkgs.writeTextDir "dconf/db" str;

    compile = dir: pkgs.runCommand "dconf-db" { } ''
      ${pkgs.dconf}/bin/dconf compile $out ${dir}
    '';

    compiled = compile "${file}/dconf";
  in
    "file-db:${compiled}";

  cfg = config.rrbutani.gsettings;
in {
  options.rrbutani.gsettings = lib.mkOption {
    type = lib.types.anything;
    default = {};
  };

  config = {
    assertions = [{
      assertion = config.services.xserver.desktopManager.gnome.enable;
      message = ''
        This module assumes the gnome desktop manager is enabled.

        Enable with:
          `services.xserver.desktopManager.gnome.enable = true;`
      '';
    }];


    # TODO: undo these hacks once `https://github.com/NixOS/nixpkgs/pull/189099`
    # is merged.
    #
    # Adding a warning so we remember.
    warnings = ["Using our custom gsettings module, as a stopgap: https://github.com/NixOS/nixpkgs/pull/189099"];

    # Note that this will shadow the default gdm config:
    # https://github.com/NixOS/nixpkgs/pull/189099/files#diff-f5360a6ed414ff1e292e501143681f1cddea53d4e9ea7ce31ef310e4dc4b378dL232-R237

    # Normally, `dconf` manages the `/etc/dconf/profiles` directory.
    #
    # https://github.com/NixOS/nixpkgs/blob/45b56b5321aed52d4464dc9af94dc1b20d477ac5/nixos/modules/programs/dconf.nix#L51-L53
    #
    # We want to suppress this so we forcibly clear dconf's profiles.
    programs.dconf.profiles = lib.mkForce {};

    environment = {
      etc = {
        "dconf/profile/user".text = "user-db:user\n" + (mkCompiledDconf cfg);

        # User readable gschema version too, just so we can see it on the
        # running system:
        "dconf/profile.d/user".text = gnome.toGnomeSettings cfg;
      };

      sessionVariables = {
        DCONF_PROFILE = "user";
      };
    };
  };
}
