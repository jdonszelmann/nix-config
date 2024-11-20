{ fetchurl
, jq
}:

# !!! There isn't a stable download URL so we parse the JSON response the
# download page yields as part of doing the fetch.
#
# We abuse `fetchurl`'s `postFetch` hook to do rather than create our own
# bespoke fixed-output derivation.
{ url, sha256, name ? "eggnogg-linux.tar.gz" }: fetchurl {
  inherit name url sha256;
  curlOptsList = ["-XPOST"];
  nativeBuildInputs = [ jq ];
  postFetch = ''
    actualUrl="$(jq -r <"$downloadedFile" '.url')"
    # Remove `-XPOST` now:
    curlOpts=("''${curl[@]}"); curl=()
    for opt in "''${curlOpts[@]}"; do
      if [[ "$opt" != '-XPOST' ]]; then curl+=("$opt"); fi
    done
    rm "$downloadedFile"
    tryDownload "$actualUrl"
  '';
}
