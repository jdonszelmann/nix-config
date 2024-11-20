{ lib }: with lib; {
  # Returns `true` if `pkg` is a derivation and is available on `system`.
  isDrvAndAvailable = { throwOnEvalError ? false, system }: path: pkg: let
    path' = if isList path then concatStringsSep "." path else path;
    chk = if throwOnEvalError then throwIfNot else warnIfNot;
    try = x: let val = builtins.tryEval x; in chk val.success ''
      Hit an evaluation error for item at `${path'}`!
    '' val.value;
    avail = try (lib.meta.availableOn system pkg);
    isDrv = try (lib.isDerivation pkg);
  in isDrv && avail;
}
