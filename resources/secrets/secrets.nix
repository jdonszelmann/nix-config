let
  inherit (import ./pub.nix) users systems;

  # Most restricted to least:
  u = users;
  s = systems ++ users;
  a = s;
in {
  "cayahuanca.age".publicKeys = a;
  "caya-b.age".publicKeys = a;
  "caya-r.age".publicKeys = a;

  "r-pass.age".publicKeys = a;
  "r-gh.age".publicKeys = a;
}
