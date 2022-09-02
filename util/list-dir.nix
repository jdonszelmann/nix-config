{ lib }:

let listDirFunc =
{ includeFilesWithExtension ? "nix"
, includeDirsWithFile ? "default.nix"
, recurse ? false
, of
, mapFunc ? n: v: v
}@args: let
  dbg = x: builtins.trace x x;

  dir = of;
  list = builtins.readDir dir;
  list' = lib.attrsets.mapAttrs' (n: v:
    if v == "directory" && includeDirsWithFile != null then
      let
        name = n;
        path = dir + "/${n}/${includeDirsWithFile}";
      in {
        inherit name;
        value = if builtins.pathExists path then path else false;
      }
    else if v == "regular" && includeFilesWithExtension != null then
      let
        suffix = ".${includeFilesWithExtension}";
        name = lib.strings.removeSuffix suffix n;
        path = dir + "/${n}";
      in {
        inherit name;
        value = if lib.strings.hasSuffix suffix n then path else false;
      }
    else {
      name = n;
      value = false;
    }
  ) list;
  filteredList = lib.attrsets.filterAttrs (_: v: v != false) list';
  res = builtins.mapAttrs mapFunc filteredList;

  extras = if recurse then
    let
      dirs = lib.attrsets.filterAttrs (n: v:
        v == "directory" &&
        # Don't recurse into directories that had the file we were looking for
        # in them (and are thus already in our results):
        !(builtins.hasAttr n filteredList)
      ) list;

      # For each directory, recurse:
      dirsOutputs = let
        steps = [
          #  { [dir name] => _ }

          #  -> { [dir name] => { [n] => v }}             # mapAttrs
          (lib.attrsets.mapAttrs (
            n: _: listDirFunc (args // { of = dir + "/${n}"; })
          ))

          #  -> { [dir name] => { [dir name + n] => v }}  # mapAttrs
          #  -> { [dir name] => [ { name; value; } ] }    # mapAttrs (mapAttrsToList)
          (lib.attrsets.mapAttrs (
            dirName: lib.attrsets.mapAttrsToList (
              name: v: {
                name = "${dirName}/${name}";
                value = v;
              }
            )
          ))

          #  -> [ [ { name; value; } ] ]                  # mapAttrsToList
          (lib.attrsets.mapAttrsToList (_: v: v))

          #  -> [ { name; value; } ]                      # flatten
          (lib.lists.flatten)

          #  -> { [name] => value }                       # listToAttrs
          (builtins.listToAttrs)
        ];
      in builtins.foldl'
        (inp: func: func inp) dirs steps
      ;
    in dirsOutputs
  else { };
in
  extras // res;

in listDirFunc