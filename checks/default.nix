# checks/default.nix
#
# EVAL-TIME checks for the nixfont module. No build, no VM: every check evaluates
# `lib.evalModules` over `modules/nixfont.nix` alone -- that file reads nothing outside its own
# `nixfont.*` options, so unlike nixarch/nixram's suites this needs no stub of a surrounding
# system-manager/NixOS surface -- and then inspects what it RENDERS into `config.nixfont`. These
# check the module's OUTPUT VALUES, never whether pacman itself actually converges on a real box.
{ pkgs, nixfontModule }:
let
  lib = pkgs.lib;

  check = name: ok: detail: { inherit name ok detail; };

  evalNixfont = extraConfig: (lib.evalModules {
    modules = [ nixfontModule extraConfig ];
  }).config;

  # THE PROPERTY THIS SUITE EXISTS TO PIN: `ttf-google-fonts-typewolf` bundles Source Sans 3 and
  # Source Serif 4 under its own package name and conflicts (without providing) with
  # adobe-source-sans-fonts/adobe-source-serif-fonts. A host that selects `source-sans` /
  # `source-serif` for the families AND `typewolf` for the other 39 must not be handed both
  # conflicting packages -- see lib/fonts.nix's `typewolf.providesInstead` and
  # modules/nixfont.nix's `autoProvidedElsewhere`.
  cfgTypewolfSelected = evalNixfont {
    nixfont.ui = [ "source-sans" "typewolf" ];
    nixfont.document = [ "source-serif" ];
  };

  # THE OTHER DIRECTION -- same font selection, minus typewolf. This is the shape a plain Arch
  # host without the bundle has always used; it must be completely unaffected by typewolf's
  # `providesInstead` existing in the catalogue at all.
  cfgTypewolfNotSelected = evalNixfont {
    nixfont.ui = [ "source-sans" ];
    nixfont.document = [ "source-serif" ];
  };

  # `archProvidedElsewhere` (the manual escape hatch) must keep working as its own, independent
  # input into the same suppression path -- proven by suppressing a name typewolf's own
  # `providesInstead` never mentions, so this cannot be passing merely because of the automatic
  # source above.
  cfgManualEscape = evalNixfont {
    nixfont.document = [ "source-serif" ];
    nixfont.archProvidedElsewhere.adobe-source-serif-fonts =
      "test fixture: pretend something else on this host already provides it";
  };
  cfgManualEscapeBaseline = evalNixfont {
    nixfont.document = [ "source-serif" ];
  };

  results = [
    (check "typewolf-selected/adobe-source-sans-suppressed"
      (!(lib.elem "adobe-source-sans-fonts" cfgTypewolfSelected.nixfont.archPackages))
      "archPackages: ${builtins.toJSON cfgTypewolfSelected.nixfont.archPackages}")

    (check "typewolf-selected/adobe-source-serif-suppressed"
      (!(lib.elem "adobe-source-serif-fonts" cfgTypewolfSelected.nixfont.archPackages))
      "archPackages: ${builtins.toJSON cfgTypewolfSelected.nixfont.archPackages}")

    # The bundle itself is AUR-only (see lib/fonts.nix), so it belongs in `aurPackages`, not
    # `archPackages` -- unrelated to suppression, but proves the fixture actually selected it.
    (check "typewolf-selected/bundle-itself-lands-in-aur-packages"
      (lib.elem "ttf-google-fonts-typewolf" cfgTypewolfSelected.nixfont.aurPackages)
      "aurPackages: ${builtins.toJSON cfgTypewolfSelected.nixfont.aurPackages}")

    # Suppression withholds the PACKAGE, not the FAMILY: `source-sans`/`source-serif` stay
    # selected (fontconfig still emits their aliases, `defaults.serif` may still name them) --
    # see archProvidedElsewhere's own doc comment on this exact promise.
    (check "typewolf-selected/families-stay-selected-despite-package-suppression"
      (lib.any (f: f.arch == "adobe-source-sans-fonts") cfgTypewolfSelected.nixfont.selected
        && lib.any (f: f.arch == "adobe-source-serif-fonts") cfgTypewolfSelected.nixfont.selected)
      "selected arch names: ${builtins.toJSON (map (f: f.arch) cfgTypewolfSelected.nixfont.selected)}")

    # THE OTHER DIRECTION. A host that never selects typewolf must get both Adobe packages
    # normally -- suppression is conditional on the bundle actually being selected, never a
    # blanket rule keyed off the catalogue alone.
    (check "typewolf-not-selected/adobe-source-sans-present"
      (lib.elem "adobe-source-sans-fonts" cfgTypewolfNotSelected.nixfont.archPackages)
      "archPackages: ${builtins.toJSON cfgTypewolfNotSelected.nixfont.archPackages}")

    (check "typewolf-not-selected/adobe-source-serif-present"
      (lib.elem "adobe-source-serif-fonts" cfgTypewolfNotSelected.nixfont.archPackages)
      "archPackages: ${builtins.toJSON cfgTypewolfNotSelected.nixfont.archPackages}")

    (check "archProvidedElsewhere/manual-escape-hatch-still-suppresses"
      (!(lib.elem "adobe-source-serif-fonts" cfgManualEscape.nixfont.archPackages))
      "archPackages: ${builtins.toJSON cfgManualEscape.nixfont.archPackages}")

    (check "archProvidedElsewhere/baseline-without-override-keeps-it"
      (lib.elem "adobe-source-serif-fonts" cfgManualEscapeBaseline.nixfont.archPackages)
      "archPackages: ${builtins.toJSON cfgManualEscapeBaseline.nixfont.archPackages}")
  ];

  failed = builtins.filter (r: !r.ok) results;

  report = lib.concatMapStringsSep "\n"
    (r: "  - ${r.name}: ${r.detail}")
    failed;
in
if failed != [ ]
then throw ''
  nixfont eval-checks FAILED (${toString (builtins.length failed)}/${toString (builtins.length results)}):
  ${report}
''
else {
  # Constructing this derivation depends on `passedCount`, which forces `results` (and therefore
  # every `check` assertion above) even if nothing else in `nix flake check` ever reads the
  # attribute -- so the checks really do run, not just get defined. See nixarch/nixram's own
  # checks/default.nix for the incident this pattern guards against: a suite written, committed,
  # and never actually reachable from any flake output.
  eval-checks = pkgs.runCommand "nixfont-eval-checks"
    { passedCount = toString (builtins.length results); }
    ''
      echo "all $passedCount nixfont eval checks passed"
      touch $out
    '';
}
