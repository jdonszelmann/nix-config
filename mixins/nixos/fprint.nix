{ ... }: {
  # Use fingerprint login:
  # (register with `fprintd-enroll`)
  rrbutani.impermanence.extra.dirs = [
    "/var/lib/fprint/"
  ];
  services.fprintd.enable = true;
}
