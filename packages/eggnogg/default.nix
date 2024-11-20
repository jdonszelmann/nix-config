# For J.
{ stdenv, lib, callPackage, fetchurl, pkgsCross, pkgsi686Linux }: let
  icon = fetchurl {
    name = "eggnogg-icon.png";
    url = "http://madgarden.net/junkz/madgarden/eggnogg/icon-1.png";
    sha256 = "sha256-BJH1KXJht3zAl9dbwq+j9os1HMUcdrCs/Fh9RaUj5u0=";
  };

  download-itch = callPackage ./download-itch.nix {};

  # TODO:
  # assert np.hostPlatform.canExecute npCross.hostPlatform
  #
  # for eggnogg classic

  # TODO: revisit/revise this...

  # Eggnogg Classic is a 32-bit x86 binary:
  #
  # Build using the cross stdenv *but* override the libraries so we can lean
  # on the cache for `i686` libraries (these don't build successfully under
  # cross yet anyways...).
  eggnogg-classic = let
    use32bitCross = stdenv.hostPlatform.isx86_64 && stdenv.hostPlatform.isLinux;
    callPackage' = if use32bitCross
      then pkgsCross.gnu32.callPackage
      else callPackage;
  in callPackage' ./classic.nix
    ((lib.optionalAttrs use32bitCross {
      inherit (pkgsi686Linux) SDL SDL_mixer libglvnd;
    }) // {
      inherit icon download-itch;
    });

  # Eggnogg Plus is a 64-bit x86 binary; no need for cross.
  eggnogg-plus = callPackage ./plus.nix { inherit icon download-itch; };
in {
  classic = eggnogg-classic;
  plus = eggnogg-plus;

  extras = { inherit eggnogg-classic eggnogg-plus; };
}
