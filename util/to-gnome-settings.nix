{ lib, pkgs ? null }: with builtins; let
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

in {
  inherit toGnomeSettings mkTuple mkUint32 mkLocation;
}
