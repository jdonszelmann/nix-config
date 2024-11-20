{ lib
, fetchFromGitHub
, buildGoModule
}: buildGoModule rec {
  pname = "sequin";
  version = "0.1.1";
  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "sequin";
    rev = "v${version}";
    hash = "sha256-QWbpX5HKX+pE/HdmqQ6dmSHZ17cFbOWVDD/s7QcrtK0=";
  };

  vendorHash = "sha256-eaWmYSPVTKtDnK/HMKzzDExKLtsXdkcALVZevMxDv+w=";

  meta = with lib; {
    description = "Human-readable ANSI sequences 🪩";
    homepage = "https://github.com/charmbracelet/sequin";
    licenses = with licenses; [ mit ];
    platforms = platforms.all;
    maintainers = with maintainers; [ rrbutani ];
  };
}

# NOTE: there is a NUR package but it comes from `GoReleaser` and doesn't build
# the binary from source:
# https://goreleaser.com/customization/nix/
# https://github.com/nix-community/nur-combined/blob/3811563141b96a5d38504edced2f77556aa2dc54/repos/charmbracelet/pkgs/sequin/default.nix
