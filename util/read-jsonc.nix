{ lib, debugPrint ? false }: let

  /* TODO: add tests, spin off into a module or something */
  readJsonC = with lib.lists; filePath: let
    trace = if debugPrint then builtins.trace else a: b: b;

    str = builtins.readFile filePath;

    # TODO: we only support simple comments and no escaping/string awareness, for now
    #
    # Something like this would let us support escapes, multi-line, etc.
    # builtins.split ("(\n)|(\/\/)|(\/\\*)|(\\*\/)" + ''|(\\")'') a

    # We don't seem to have non-greedy regex matching?
    # https://github.com/NixOS/nix/issues/4758#issuecomment-1064749823
    #
    # So watch out!
    chunks = builtins.split "(\n)|(/\/\)|(\/\\*.*?\\*\/)"
      (trace "read: \"${str}\"" str);

    car = builtins.head;
    cdr = builtins.tail;

    dbg = x: trace x x;
    isMultipleOfTwo = x: x == (2 * (x / 2));
    paired = with builtins; l: let
      len = length l;
    in
      assert isMultipleOfTwo len;
      genList (
        i: [ (elemAt l (2 * i)) (elemAt l ((2 * i) + 1)) ]
      ) (len / 2);
    
    stripped = with builtins; let
      # There is reliably a trailing string in `builtins.split`.
      end = elemAt chunks ((length chunks) - 1);

      # Drop the last element.
      rest = take ((length chunks) - 1) chunks;

      # Bunch of `(string, pattern)` pairs.
      p = paired rest;

      pairs = builtins.map (
        val: let
          str = elemAt val 0;
          pat = elemAt val 1;
        in { inherit str pat; }
      ) p;

      transforms = [
        # Rewrite anything that matched group 3 (multiline comments):
        (map (
          inp@{ str, pat }: if (elemAt pat 2) == null then
            inp
          else
            { inherit str; pat = [{
                multilineComment = assert (
                  (length (filter (x: x != null) pat)) == 1
                ); (elemAt pat 2);
              }];
            }
        ))

        # Filter out nulls, assert that there's only 1 pattern that
        # matched.
        (map (
          { str, pat }: let
            pat' = filter (v: v != null) pat;
            pat'' = assert (length pat') == 1; car pat';
          in { inherit str; pat = pat''; }
        ))

        # (map  (
        #   { str, pat }: builtins.trace "" (builtins.trace (toJSON str) (builtins.trace (toJSON pat) str))
        # ))
        # (filter (x: x == null))
      ];
      transformed = foldl' (l: func: func l) pairs transforms;

      removeComments = { list, waitingForNewl ? false }: let
        first = car list;
        rest = cdr list;

        inherit (first) str pat;
        kind = if pat == "\n" then "endsWtihNewl" else
          if pat == "//" then "endsWithCommentStart" else
          if pat ? multilineComment then "endsWithMultilineComment" else
          builtins.throw ("illegal pat: " + pat);

        curr = rest: if waitingForNewl then
          (trace " dropping `${toJSON str}`" rest) else
          [ (trace "emitting: ${toJSON str}" str) ] ++ rest; 
        rest' = let
          waiting = {
            endsWtihNewl = {
              # Got our newline, no longer waiting.
              waiting = trace "-comment over" false;
              # Still not waiting.
              not = false;
            };
            endsWithCommentStart = {
              # Looks like we have a single line comment within a single line
              # comment (i.e. `// // foo `)
              waiting = trace " continued single line comment" true;
              # new comment!
              not = trace "+new comment start" true;
            };
            endsWithMultilineComment = let
              ctx = trace " dropping multiline comment `${toJSON pat.multilineComment}`";
            in {
              waiting = ctx true;
              not = ctx false;
            };
          }.${kind}.${if waitingForNewl then "waiting" else "not"};
        in removeComments { list = rest; waitingForNewl = waiting; };
      in if list == [] then [] else (
        curr rest'
      );

      stripped = removeComments { list = transformed; };
    in
      (toString stripped) + (trace "emitting: ${toJSON end}" end);

  in
    builtins.fromJSON stripped;

in
  readJsonC