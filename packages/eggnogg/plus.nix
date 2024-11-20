{ lib
, stdenvNoCC
, autoPatchelfHook
, makeDesktopItem
, copyDesktopItems
, makeWrapper
, unzip

, download-itch
, icon

, SDL2
, libglvnd
}: stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "eggnoggplus";
  version = "BETA"; # see `data/greetz.txt`
  src = download-itch {
    name = "eggnoggplus-linux.zip";
    url = "https://madgarden.itch.io/eggnogg/file/138869?source=game_download";
    sha256 = "sha256-U/rIGEZ4h3CFr1HRaWhthm9nmyGhTVkRXbw8M/PRd+M=";
  };

  nativeBuildInputs = [ autoPatchelfHook copyDesktopItems makeWrapper unzip ];
  buildInputs = [
    SDL2
    libglvnd
  ];

  desktopItems = [
    (makeDesktopItem rec {
      name = "Eggnogg+";
      exec = finalAttrs.pname;
      inherit icon;
      comment = finalAttrs.meta.description;
      desktopName = name;
      genericName = name;
      categories = [ "Game" ];
    })
  ];

  installPhase = ''
    mkdir -p $out/bin $out/share/applications
    mv data $out/
    copyDesktopItems
    # game expects `pwd` to contain the `data` directory!
    mv $pname $out/bin
    wrapProgram $out/bin/$pname --chdir "$out"
  '';

  # binary doesn't read cli args; no easy way to test..

  # TODO: unfree?
  meta = {
    description = "A competitive arcade game of immortals sword-fighting to the death.";
    homepage = "https://madgarden.itch.io/eggnogg";
    maintainers = with lib.maintainers; [ rrbutani ];
    # requires a platform that can run 64-bit x86 code!
    platforms = with lib.systems.inspect; [ patterns.isx86_64 ]; # TODO: macOS?
    badPlatforms = with lib.systems.inspect; [ platformPatterns.isStatic ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
