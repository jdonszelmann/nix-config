{ lib
, stdenvNoCC
, autoPatchelfHook
, makeDesktopItem
, copyDesktopItems
, makeWrapper

, download-itch
, icon

# Need to be for `i686-linux` when targeting Linux.
, SDL
, SDL_mixer
, libglvnd
}: stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "eggnogg";
  version = "1.3.1"; # see `data/greetz.txt`
  src = download-itch {
    url = "https://madgarden.itch.io/eggnogg/file/908?after_download_lightbox=true";
    sha256 = "sha256-stMP+/0OaqUkdQfPY0g6TtoR/lDD5+hJ3pdZJhDQvFQ=";
  };

  nativeBuildInputs = [ autoPatchelfHook copyDesktopItems makeWrapper ];
  buildInputs = [
    SDL
    SDL_mixer
    libglvnd
  ];

  desktopItems = [
    (makeDesktopItem rec {
      name = "Eggnogg";
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
    # requires a platform that can run 32-bit x86 code!
    platforms = with lib.systems.inspect; [ patterns.isx86/*_32*/ ]; # TODO: macOS?
    badPlatforms = with lib.systems.inspect; [ platformPatterns.isStatic ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
