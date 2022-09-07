{ iosevka }: let
  # See https://typeof.net/Iosevka/customizer
  config = {
    family = "Iosevka Custom";
    spacing = "quasi-proportional";
    serifs = "sans";
    no-cv-ss = true;
    export-glyph-names = false;

    variants.inherits = "ss17";
  };
in iosevka.override { privateBuildPlan = config; set = "mono"; }

# TODO: use iosevka-comfy instead?
