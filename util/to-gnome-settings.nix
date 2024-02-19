{ lib }: with builtins; let
  primitives = {
    list = l: "[${concatStringsSep ", " (map primMap l)}]";
    string = s: "'${s}'";
    path = p: primitives.string "file://${p}";
    int = toString;
    float = toString;
    bool = b: if b then "true" else "false";
    custom = x: x.gen x;
  };
  getType = v: let
    type-raw = typeOf v;
    type = if type-raw == "set" && v ? gen && v ? __customType then "custom" else type-raw;
  in type;
  isPrim = v: let
    type = getType v;
  in hasAttr type primitives;
  primMap = p: let
    type = getType p;
  in (primitives.${type} or
    (builtins.throw "illegal non-primitive value (type = ${type}): ${toString p}")
  ) p;

  # TODO
  validateKey = currPath: x: let
    chars = lib.stringToCharacters x;
    disallowed = [ "/" "." "\n" "\t" "(" ")" ];
    disallowed' = listToAttrs (map (v: { name = v; value = true; }) disallowed);

    valid = all (
      c: if disallowed'.${c} or false then
        throw "`${currPath}/${x}` is not a valid key; `${x}` contains an invalid character: `${c}`."
      else
        true
    ) chars;
  in if valid then x else throw "unreachable";

  mkTuple = l: {
    __customType = "tuple";
    list = l;
    gen = self: "(${concatStringsSep ", " (map primMap self.list)})";
  };

  mkUint32 = i: {
    __customType = "uint32";
    val = if (typeOf i) == "int" then i else builtins.throw "uint32 requires an integer";
    gen = s: "uint32 ${toString s.val}";
  };

  # ???
  mkLocation = locList: {
    __customType = "av";
    val = locList;
    gen = self: "@av ${primitives.list self.val}";
  };

  # TODO: spin this off, maybe send to upstream, enable
  # merging, etc?
  #
  # TODO: key validation (for illegal chars)
  toGnomeSettings = attrset: let
    convert = currPath: set: let
      children = lib.mapAttrsToList (n: v: n) set;
      setChildren = filter (n: !(isPrim set.${n})) children;
      nonSetChildren = filter (n: isPrim set.${n}) children;

      imm = "[${currPath}]\n" + (concatStringsSep "" (map (
        k: let
          v = set.${k};
          val-try = tryEval (deepSeq (primMap v) (primMap v));
          val = if val-try.success then val-try.value else
            lib.warn
              "enountered an illegal value at `${currPath}/${k}`:"
              primMap v;
        in
          "${validateKey currPath k}=${val}" + "\n"
      ) nonSetChildren)) + "\n";

      setChildrenNodes = concatStringsSep "" (map (
        k: convert "${currPath}${if currPath != "" then "/" else ""}${validateKey currPath k}" set.${k}
      ) setChildren);
    in if (lib.lists.length nonSetChildren) == 0 then
      setChildrenNodes
    else
      imm + setChildrenNodes;
  in
    convert "" attrset;

  tests = { big = {
    attrset = {
      org.gnome = {
        Geary.migrated-config = true;

        control-center = {
          last-panel = "keyboard";
          window-state = mkTuple [980 640 false];
        };

        desktop = {
          app-folders = {
            folder-children = ["Utilities" "YaST"];
            folders = {
              Utilities = {
                apps = [
                  "gnome-abrt.desktop"
                  "gnome-system-log.desktop"
                  "nm-connection-editor.desktop"
                  "org.gnome.baobab.desktop"
                  "org.gnome.Connections.desktop"
                  "org.gnome.DejaDup.desktop"
                  "org.gnome.Dictionary.desktop"
                  "org.gnome.DiskUtility.desktop"
                  "org.gnome.eog.desktop"
                  "org.gnome.Evince.desktop"
                  "org.gnome.FileRoller.desktop"
                  "org.gnome.fonts.desktop"
                  "org.gnome.seahorse.Application.desktop"
                  "org.gnome.tweaks.desktop"
                  "org.gnome.Usage.desktop"
                  "vinagre.desktop"
                ];
                categories = ["X-GNOME-Utilities"];
                name = "X-GNOME-Utilities.directory";
                translate = true;
              };

              YaST = {
                categories = ["X-SuSE-YaST"];
                name = "suse-yast.directory";
                translate = true;
              };
            };
          };

          background = {
            color-shading-type = "solid";
            picture-options = "zoom";
            picture-uri = /run/current-system/sw/share/backgrounds/gnome/blobs-l.svg;
            picture-uri-dark = /run/current-system/sw/share/backgrounds/gnome/blobs-d.svg;
            primary-color = "#3465a4";
            secondary-color = "#000000";
          };

          input-sources = {
            sources = [
              (mkTuple [ "xkb" "us" ])
            ];
            xkb-options = [
              "terminate:ctrl_alt_bksp"
              "caps:ctrl_modifier"
              "shift:both_capslock"
              "compose:ralt"
            ];
          };

          interface = {
            color-scheme = "prefer-dark";
            show-battery-percentage = true;
          };

          notifications.application-children = [ "org-gnome-console" "firefox" ];
          notifications.application = {
            org-gnome-console.application-id = "org.gnome.Console.desktop";
            firefox.application-id = "firefox.desktop";
          };

          peripherals.touchpad = {
            speed = 0.027778;
            tap-to-click = true;
            two-finger-scrolling-enabled = true;
          };

          privacy = {
            old-files-age = mkUint32 30;
            recent-files-max-age = -1;
          };

          screensaver = {
            color-shading-type = "solid";
            lock-delay = mkUint32 0;
            picture-options = "zoom";
            picture-uri = /run/current-system/sw/share/backgrounds/gnome/blobs-l.svg;
            primary-color = "#3465a4";
            secondary-color = "#000000";
          };

          search-providers.sort-order = [
            "org.gnome.Contacts.desktop"
            "org.gnome.Documents.desktop"
            "org.gnome.Nautilus.desktop"
          ];

          session.idle-delay = mkUint32 240;

          sound = {
            event-sounds = true;
            theme-name = "__custom";
          };

          wm.keybindings = {
            move-to-workspace-left = [ "<Alt><Super>Left" ];
            move-to-workspace-right = [ "<Alt><Super>Right" ];
            switch-group = [ "<Super>grave" ];
            switch-group-backward = [ "<Shift><Super>grave" ];
            switch-to-workspace-left = [ "<Super>Left" ];
            switch-to-workspace-right = [ "<Super>Right" ];
            toggle-fullscreen = [ "<Shift><Super>f" ];
          };
        };

        evolution-data-server = {
          migrated = true;
          network-monitor-gio-name = "";
        };

        mutter = {
          attach-modal-dialogs = true;
          dynamic-workspaces = true;
          edge-tiling = true;
          focus-change-on-pointer-rest = true;
          workspaces-only-on-primary = false;

          keybindings = {
            toggle-tiled-left = [ "<Control><Super>Left" ];
            toggle-tiled-right = [ "<Control><Super>Right" ];
          };
        };

        settings-daemon.plugins = {
          color = {
            night-light-enabled = true;
            night-light-temperature = mkUint32 2845;
          };

          media-keys = {
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/user-defined/custom0/"
            ];
            next = [ "0x100811be" ];
            play = [ "Favorites" ];
            previous = [ "0x100811bd" ];
            www = [ "<Super>b" ];

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
          welcome-dialog-last-shown-version="42.4";

          app-switcher.current-workspace-only = true;

          keybindings = {
            show-screen-recording-ui = [ "<Shift><Super>r" ];
            show-screenshot-ui = [ "<Shift><Super>s" ];
          };

          world-clocks.locations = mkLocation [];
        };
      };

      system.proxy.mode = "none";
    };
    expected = ''
      [org/gnome/Geary]
      migrated-config=true

      [org/gnome/control-center]
      last-panel='keyboard'
      window-state=(980, 640, false)

      [org/gnome/desktop/app-folders]
      folder-children=['Utilities', 'YaST']

      [org/gnome/desktop/app-folders/folders/Utilities]
      apps=['gnome-abrt.desktop', 'gnome-system-log.desktop', 'nm-connection-editor.desktop', 'org.gnome.baobab.desktop', 'org.gnome.Connections.desktop', 'org.gnome.DejaDup.desktop', 'org.gnome.Dictionary.desktop', 'org.gnome.DiskUtility.desktop', 'org.gnome.eog.desktop', 'org.gnome.Evince.desktop', 'org.gnome.FileRoller.desktop', 'org.gnome.fonts.desktop', 'org.gnome.seahorse.Application.desktop', 'org.gnome.tweaks.desktop', 'org.gnome.Usage.desktop', 'vinagre.desktop']
      categories=['X-GNOME-Utilities']
      name='X-GNOME-Utilities.directory'
      translate=true

      [org/gnome/desktop/app-folders/folders/YaST]
      categories=['X-SuSE-YaST']
      name='suse-yast.directory'
      translate=true

      [org/gnome/desktop/background]
      color-shading-type='solid'
      picture-options='zoom'
      picture-uri='file://${/run/current-system/sw/share/backgrounds/gnome/blobs-l.svg}'
      picture-uri-dark='file://${/run/current-system/sw/share/backgrounds/gnome/blobs-d.svg}'
      primary-color='#3465a4'
      secondary-color='#000000'

      [org/gnome/desktop/input-sources]
      sources=[('xkb', 'us')]
      xkb-options=['terminate:ctrl_alt_bksp', 'caps:ctrl_modifier', 'shift:both_capslock', 'compose:ralt']

      [org/gnome/desktop/interface]
      color-scheme='prefer-dark'
      show-battery-percentage=true

      [org/gnome/desktop/notifications]
      application-children=['org-gnome-console', 'firefox']

      [org/gnome/desktop/notifications/application/firefox]
      application-id='firefox.desktop'

      [org/gnome/desktop/notifications/application/org-gnome-console]
      application-id='org.gnome.Console.desktop'

      [org/gnome/desktop/peripherals/touchpad]
      speed=0.027778
      tap-to-click=true
      two-finger-scrolling-enabled=true

      [org/gnome/desktop/privacy]
      old-files-age=uint32 30
      recent-files-max-age=-1

      [org/gnome/desktop/screensaver]
      color-shading-type='solid'
      lock-delay=uint32 0
      picture-options='zoom'
      picture-uri='file://${/run/current-system/sw/share/backgrounds/gnome/blobs-l.svg}'
      primary-color='#3465a4'
      secondary-color='#000000'

      [org/gnome/desktop/search-providers]
      sort-order=['org.gnome.Contacts.desktop', 'org.gnome.Documents.desktop', 'org.gnome.Nautilus.desktop']

      [org/gnome/desktop/session]
      idle-delay=uint32 240

      [org/gnome/desktop/sound]
      event-sounds=true
      theme-name='__custom'

      [org/gnome/desktop/wm/keybindings]
      move-to-workspace-left=['<Alt><Super>Left']
      move-to-workspace-right=['<Alt><Super>Right']
      switch-group=['<Super>grave']
      switch-group-backward=['<Shift><Super>grave']
      switch-to-workspace-left=['<Super>Left']
      switch-to-workspace-right=['<Super>Right']
      toggle-fullscreen=['<Shift><Super>f']

      [org/gnome/evolution-data-server]
      migrated=true
      network-monitor-gio-name='' + "''" + "\n" + ''

      [org/gnome/mutter]
      attach-modal-dialogs=true
      dynamic-workspaces=true
      edge-tiling=true
      focus-change-on-pointer-rest=true
      workspaces-only-on-primary=false

      [org/gnome/mutter/keybindings]
      toggle-tiled-left=['<Control><Super>Left']
      toggle-tiled-right=['<Control><Super>Right']

      [org/gnome/settings-daemon/plugins/color]
      night-light-enabled=true
      night-light-temperature=uint32 2845

      [org/gnome/settings-daemon/plugins/media-keys]
      custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/user-defined/custom0/']
      next=['0x100811be']
      play=['Favorites']
      previous=['0x100811bd']
      www=['<Super>b']

      [org/gnome/settings-daemon/plugins/media-keys/user-defined/custom0]
      binding='<Super>t'
      command='kgx'
      name='Open Terminal'

      [org/gnome/settings-daemon/plugins/power]
      power-button-action='suspend'

      [org/gnome/shell]
      welcome-dialog-last-shown-version='42.4'

      [org/gnome/shell/app-switcher]
      current-workspace-only=true

      [org/gnome/shell/keybindings]
      show-screen-recording-ui=['<Shift><Super>r']
      show-screenshot-ui=['<Shift><Super>s']

      [org/gnome/shell/world-clocks]
      locations=@av []

      [system/proxy]
      mode='none'
    '' + "\n";
  }; };
  test = { pkgs ? null, name, attrset, expected }: let
    got = toGnomeSettings attrset;
  in
    if pkgs != null then
      pkgs.runCommand "gnome-settings-test-${name}"
        { inherit got expected; passAsFile = [ "got" "expected" ]; }
      ''
        ${pkgs.colordiff}/bin/colordiff -y <(cat -te $expectedPath) <(cat -te $gotPath)
        touch $out
      ''
    else if got == expected then
      true
    else
      throw "expected:\n```\n${expected}\n```\n\ngot:\n```\n${got}\n"
    ;

  # This situation is easy to workaround; not sure if this is always true though..
  uh-oh = ''
    [org/gnome/settings-daemon/plugins/media-keys]
    custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']
    next=['0x100811be']
    play=['Favorites']
    previous=['0x100811bd']
    www=['<Super>b']

    [org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0]
    binding='<Super>t'
    command='kgx'
    name='Open Terminal'
  '';

  checks = { pkgs }: lib.mapAttrs
    (name: attrs: test (attrs // { inherit name pkgs; }))
    tests
  ;
in {
  inherit toGnomeSettings mkTuple mkUint32 mkLocation checks;
}
