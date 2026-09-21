# SPDX-License-Identifier: MIT OR Apache-2.0
#
# nixfont — fonts as a shared concern, not a corner of somebody else's module.
#
# WHY ITS OWN MODULE. Fonts are consumed by four unrelated domains at once: the terminal wants a
# nerd/mono family, the desktop UI wants a sans, documents want metric-compatible families, and
# PRINTING wants gsfonts because ghostscript needs it for PostScript. If an office module owned
# fonts, a desktop module would have to depend on the office module to get its UI font -- and a
# headless box rendering PDFs would have to pull in a desktop it does not have. So fonts are a
# dependency OF those modules rather than owned by any one of them.
#
# It is also more than a package list: the useful part is telling fontconfig which family is the
# default sans, serif and monospace, which is real generated config.
{ config, lib, ... }:
let
  cfg = config.nixfont;
  catalogue = import ../lib/fonts.nix { };

  mkGroup = what: table: lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames table));
    default = [ ];
    description = "Which ${what} to install. Available: ${lib.concatStringsSep ", " (lib.attrNames table)}.";
  };

  selected = lib.flatten [
    (map (k: catalogue.ui.${k}) cfg.ui)
    (map (k: catalogue.mono.${k}) cfg.mono)
    (map (k: catalogue.document.${k}) cfg.document)
    (map (k: catalogue.coverage.${k}) cfg.coverage)
  ];

  # Every catalogue entry, keyed by its own table key, regardless of which of the four groups it
  # lives in. `providesInstead` (see lib/fonts.nix's `typewolf` entry) names catalogue keys, not
  # package names, and the entry it substitutes for need not share its group -- typewolf lives in
  # `ui` but substitutes for `document.source-serif` as well as `ui.source-sans`. A single flat
  # lookup resolves either without teaching each group about its siblings.
  allEntries = lib.foldl' (acc: group: acc // group) { } (lib.attrValues catalogue);

  # Pacman package names automatically withheld from the reconciler because a SELECTED entry's
  # own `providesInstead` says it already ships that family under a different package. This is
  # exactly the same fact `archProvidedElsewhere` below lets an operator state by hand -- computed
  # here instead so it is expressed once, on the catalogue entry actually responsible for it,
  # rather than rediscovered by every host that selects the bundle (see lib/fonts.nix's `typewolf`
  # comment for why that makes it the bundle's property, not a selecting host's).
  #
  # Folded over `selected`, not the raw catalogue: an entry's `providesInstead` must contribute
  # nothing unless that entry itself was actually picked, or a host that never selects typewolf
  # would lose the Adobe packages it never conflicted with in the first place.
  autoProvidedElsewhere = lib.foldl'
    (acc: f: acc // lib.genAttrs
      (map (k: allEntries.${k}.arch) (f.providesInstead or [ ]))
      (pkg: "${f.arch} bundles this family under a different package name (see lib/fonts.nix)"))
    { }
    selected;

  # The manual escape hatch always wins a key collision: an operator who wrote their own reason
  # for a name should see THEIR string, not one this module generated. Both sources feed the one
  # suppression path below (`wantedOnArch`) -- this module has only ever had the one mechanism.
  allProvidedElsewhere = autoProvidedElsewhere // cfg.archProvidedElsewhere;

  # The families the SELECTED entries are actually known to render as, deduped. Only entries
  # lib/fonts.nix could verify carry `families` at all -- see that file's header for why some are
  # deliberately `[ ]` rather than guessed. This is therefore a floor, not a ceiling: a `defaults`
  # value missing from it might still be a real, installed family this catalogue never verified.
  selectedFamilies = lib.unique (lib.flatten (map (f: f.families or [ ]) selected));

  # `defaults.*` as a uniform list, so the check below is one filter instead of four copies of it.
  namedDefaults = lib.filterAttrs (_: v: v != null) cfg.defaults;

  # The whole reason this exists: naming a font in `defaults` that nothing selected does not fail
  # -- it silently substitutes, which is how a fleet's terminal spent weeks rendering in a
  # proportional face over a stale `font=Hack` nobody had installed in years. A value present here
  # was typed but never selected (or a typo of something that was); one string per offender,
  # ready to hand straight to a platform backend's `warnings`.
  unmatchedDefaults = lib.mapAttrsToList
    (generic: family: ''
      nixfont: defaults.${generic} = "${family}" does not match any selected font's known family
      name (known: ${if selectedFamilies == [ ] then "none catalogued for this selection" else lib.concatStringsSep ", " selectedFamilies}).
      Either it is a typo, or the catalogue entry that ships it was never added to nixfont.ui/mono/document/coverage.'')
    (lib.filterAttrs (_: family: !(lib.elem family selectedFamilies)) namedDefaults);

  # Arch only. A font declared here is still SELECTED -- it stays in `selected`, so fontconfig
  # still emits its alias and `unavailableOnNixos` still counts it. All that changes is that this
  # host does not ask pacman to install that particular package, because something else on the box
  # already carries the family. Tested against `allProvidedElsewhere` (manual + auto-derived),
  # never `cfg.archProvidedElsewhere` alone -- see that option's own doc comment.
  wantedOnArch = f: !(allProvidedElsewhere ? ${f.arch});

  # fontconfig's <alias> blocks: what "sans-serif" and friends actually resolve to. Written only
  # for the families the host asked for -- naming a default this host did not install is how you
  # get silent fallback to whatever fontconfig picks alphabetically.
  aliasFor = generic: family: lib.optionalString (family != null) ''
      <alias>
        <family>${generic}</family>
        <prefer><family>${family}</family></prefer>
      </alias>
  '';
in
{
  options.nixfont = {
    ui = mkGroup "interface fonts" catalogue.ui;
    mono = mkGroup "monospace/terminal fonts" catalogue.mono;
    document = mkGroup "document and print-compatibility fonts" catalogue.document;
    coverage = mkGroup "Unicode coverage fonts" catalogue.coverage;

    defaults = {
      sans = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Family name fontconfig resolves `sans-serif` to, e.g. \"Inter\". Null leaves fontconfig's own default alone.";
      };
      serif = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Family name for `serif`.";
      };
      monospace = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Family name for `monospace`, e.g. \"GeistMono Nerd Font\".";
      };
      emoji = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Family appended as a last-resort fallback for every generic, so emoji render instead of tofu.";
      };
    };

    fontconfig = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = "Generated fontconfig fragment. Both backends write this to the platform's conf.d.";
    };

    selected = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      description = ''
        The resolved catalogue entries for every family named in `ui`/`mono`/`document`/
        `coverage`, in one flat list. The canonical "what did this host actually ask for" --
        both platform backends should derive package lists from THIS, not re-categorize by
        Arch's own AUR/pacman split the way an earlier version of the NixOS backend did (a
        font that only exists in the AUR on Arch has no AUR at all on NixOS; excluding it from
        `fonts.packages` because of an Arch-only distinction silently dropped it there).
      '';
    };

    selectedFamilies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Deduped fontconfig family names contributed by `families` on every selected catalogue
        entry (see lib/fonts.nix). A floor, not a ceiling: entries lib/fonts.nix could not verify
        contribute nothing here even when installed and real, so a `defaults` value missing from
        this list is not proof it is wrong -- only `unmatchedDefaults` below draws that
        conclusion, and only after also checking there is nothing to vouch for it.
      '';
    };

    unmatchedDefaults = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        One ready-to-print warning per `defaults.*` value that names a family nothing selected
        actually provides. Both backends should fold this into their own `warnings`. Empty is not
        proof every default is correct -- lib/fonts.nix leaves some entries' `families` empty on
        purpose (see its header) -- but a non-empty result is real: the string was typed and
        nothing selected backs it, which is exactly the shape of the bug this exists to catch.
      '';
    };

    archPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Selected fonts as pacman package names, for a host's own reconciler to consume.";
    };

    aurPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Selections that live in the AUR rather than an official repo, kept SEPARATE because
        `pacman -S` cannot resolve them -- it fails the whole transaction with "target not found",
        which takes the rest of the converge down with it. Wire them to the AUR side:

          nixarch.packages.aur = config.nixfont.aurPackages;

        With no `aurUser` configured the reconciler skips them with a warning, which is the right
        failure mode: the packages stay as they are and nothing else breaks.
      '';
    };

    archProvidedElsewhere = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          adobe-source-sans-fonts = "ttf-google-fonts-typewolf ships Source Sans 3 and conflicts with it";
        }
      '';
      description = ''
        Pacman package names this host gets from a DIFFERENT package, mapped to why. They are
        dropped from `archPackages`/`aurPackages`; the family itself stays selected, because the
        font is still on the box and `defaults` may legitimately name it.

        This exists for Arch's `provides`/`conflicts` pairs. A bundle like
        `ttf-google-fonts-typewolf` provides forty families at once and conflicts with each
        individual package, so `pacman -S` on any of them dies with "unresolvable package
        conflicts" and takes the whole converge with it. The only two ways out are to uninstall
        the bundle -- losing the other thirty-nine families to satisfy a package *name* while the
        font itself was never missing -- or to say so here.

        A reason is mandatory rather than a bare list: an entry here is invisible in the resulting
        package set, so six months later the only evidence it was deliberate is the string.

        This is the CONSUMER-FACING escape hatch for a conflict lib/fonts.nix does not (yet) know
        about. Where the catalogue itself already knows -- typewolf's own `providesInstead`, see
        its comment in lib/fonts.nix -- nixfont derives the same suppression automatically and a
        host selecting that bundle need not repeat it here at all. The two sources merge (this
        option wins a key collision, since a hand-written reason should never be silently
        replaced) and both feed the identical `archPackages`/`aurPackages` filtering; this option
        is for the conflicts the catalogue does not model, not a duplicate mechanism.
      '';
    };

    unavailableOnNixos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Selections with no nixpkgs equivalent, surfaced rather than silently dropped.";
    };
  };

  config = {
    nixfont.selected = selected;
    nixfont.selectedFamilies = selectedFamilies;
    nixfont.unmatchedDefaults = unmatchedDefaults;

    nixfont.archPackages =
      lib.unique (map (f: f.arch) (lib.filter (f: !(f.aur or false) && wantedOnArch f) selected));
    nixfont.aurPackages =
      lib.unique (map (f: f.arch) (lib.filter (f: (f.aur or false) && wantedOnArch f) selected));
    nixfont.unavailableOnNixos =
      lib.unique (map (f: f.arch) (lib.filter (f: f.nixpkgs == null) selected));

    nixfont.fontconfig = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <!-- Generated by nixfont. Do not edit. -->
      <fontconfig>
      ${aliasFor "sans-serif" cfg.defaults.sans}${aliasFor "serif" cfg.defaults.serif}${aliasFor "monospace" cfg.defaults.monospace}${lib.optionalString (cfg.defaults.emoji != null) ''
      ${lib.concatMapStringsSep "\n" (g: ''
        <alias>
          <family>${g}</family>
          <accept><family>${cfg.defaults.emoji}</family></accept>
        </alias>'') [ "sans-serif" "serif" "monospace" ]}
      ''}</fontconfig>
    '';
  };
}
