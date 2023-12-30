let
  pub = import ./pub.nix;
  inherit (pub) users systems;

  # Most restricted to least:
  u = users;
  s = systems ++ users;
  a = s;

  work = "";
  i = [ pub.cayahuanca pub.rahul ];
in {
  "cayahuanca.age".publicKeys = a;
  "caya-b.age".publicKeys = a;
  "caya-r.age".publicKeys = a;

  "r-pass.age".publicKeys = a;
  "r-ssh.age".publicKeys = a;
}
