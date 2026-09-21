# SPDX-License-Identifier: MIT OR Apache-2.0
#
# The font catalogue: one entry per family, named on each platform.
#
# `arch` is the pacman package, `nixpkgs` the attribute (or null where there is no equivalent).
# Fonts are unusually prone to name drift between distros -- `ttf-liberation` vs `liberation_ttf`,
# `ttf-ms-fonts` vs `corefonts` -- which is the whole reason this table exists rather than a bare
# list of package names in each consumer.
#
# `families` (optional, default [ ]) is the DIFFERENT drift problem: not the package name, but
# what fontconfig actually calls the font once installed -- the string an operator types into
# `defaults.sans`/`.serif`/`.monospace`/`.emoji`. It exists so nixfont.nix can catch a `defaults`
# value that names a font nobody selected (see that module's `unmatchedDefaults`): naming an
# uninstalled font does not fail, it silently substitutes, which is exactly how one fleet's
# terminal spent weeks rendering in a proportional face over a stale `font=Hack`.
#
# Populated only where verification was possible against a real, installed system (`fc-scan`
# over every file `pacman -Ql <pkg>` lists, cross-checked on two independent hosts) AND the name
# is stable across font versions. Left `[ ]` -- not guessed -- for two different reasons:
#   - genuinely too large to be useful (noto/noto-extra each cover 100-250+ scripts; enumerating
#     them here would dwarf the catalogue for families nothing sane names as a single `defaults`
#     value anyway), or
#   - the family name embeds a version an upstream can bump (Font Awesome's family literally
#     reads "Font Awesome 6 Free" vs "...7 Free" depending on which major you have installed --
#     unlike a typeface name, that string is not stable to hardcode).
# An empty `families` means "not validated", never "not installed": nixfont.nix only warns on a
# NAMED mismatch, it never claims absence.
{ ... }:
{
  # ── UI / interface ──────────────────────────────────────────────────────────────────────────
  ui = {
    inter = { arch = "inter-font"; nixpkgs = "inter"; families = [ "Inter" ]; };
    cantarell = { arch = "cantarell-fonts"; nixpkgs = "cantarell-fonts"; families = [ "Cantarell" ]; };
    # AUR otf-geist, NOT ttf-geist. Both build the same upstream Vercel/Basement Studio family,
    # but only one of them is what fontconfig actually resolves: `fc-match Geist` ->
    # Geist-Regular.otf (confirmed live, 2026-08-04, on a host with both ttf-geist and otf-geist
    # installed side by side). ttf-geist was declared here for months while the OTF build quietly
    # did the rendering — a real package installed for a family that was never the one on screen.
    # There is also a `ttf-geist-variable` AUR build; deliberately NOT declared, ever: `fc-list |
    # grep -ci "geist.*variable"` returns 0 on a live host with it installed — it registers no
    # faces at all, inert. Both otf-geist and otf-geist-mono are AUR-only, confirmed via
    # `paru -Si otf-geist`/`otf-geist-mono` -> `Repository: aur` (no official Arch repo package
    # exists for either), matching the AUR flag ttf-geist already carried.
    geist = { arch = "otf-geist"; nixpkgs = "geist-font"; aur = true; families = [ "Geist" ]; };
    source-sans = { arch = "adobe-source-sans-fonts"; nixpkgs = "source-sans"; families = [ "Source Sans 3" ]; };
    # AUR-only curated bundle: 40 Google Fonts hand-picked by Typewolf (typewolf.com/google-fonts)
    # for UI/branding work -- source-sans above is one of the 40 it also ships, which is why
    # `archProvidedElsewhere`'s own doc comment in modules/nixfont.nix already uses this exact
    # package as its worked example (it `provides` and `conflicts` with all 40 individual ttf-*
    # packages at once, adobe-source-sans-fonts included).
    # Confirmed AUR-only: `pacman -Qm` lists it installed (20260112-1) but
    # `pacman -Si ttf-google-fonts-typewolf` finds nothing in the official repos (2026-08-07,
    # a live host with it installed).
    # nixpkgs's own `google-fonts` attribute is the entire Google Fonts corpus (thousands of
    # families) -- a different scope, not a name-drift rename of this curated 40 -- so left null
    # rather than pointed at something far wider than what this catalogue entry means.
    # By far the largest single package in nixfont's catalogue: 113.86 MiB installed (`pacman -Qi`,
    # same host/date) -- a host enabling this is taking that weight on deliberately.
    #
    # `providesInstead`: the bundle ships Source Sans 3 and Source Serif 4 -- the exact TYPEFACES
    # `source-sans`/`source-serif` above resolve to -- packaged under ITS OWN name, not under
    # adobe-source-sans-fonts/adobe-source-serif-fonts. Pacman's `provides`/`conflicts` metadata
    # only ever talks about package NAMES, so it has no way to know the bundle already covers what
    # those two packages would install; all it can see is the conflict (see
    # modules/nixfont.nix's `archProvidedElsewhere` for what an unresolved conflict does to a
    # `pacman -S` transaction). That makes the substitution a fact about THIS BUNDLE, not about
    # whichever host happens to select it, so it belongs here rather than being rediscovered by
    # every consumer. Named as catalogue KEYS, not raw package names, so a future rename of either
    # Adobe package's `arch` value is picked up automatically instead of silently going stale.
    # modules/nixfont.nix folds this into the exact same suppression `archProvidedElsewhere`
    # already drives, and only when typewolf itself is selected -- see that module's own comment.
    typewolf = {
      arch = "ttf-google-fonts-typewolf"; nixpkgs = null; aur = true;
      providesInstead = [ "source-sans" "source-serif" ];
    };
  };

  # ── Monospace / terminal ────────────────────────────────────────────────────────────────────
  mono = {
    # otf-geist-mono, not ttf-geist-mono — same fc-match evidence as `ui.geist` above:
    # `fc-match "Geist Mono"` -> GeistMono-Regular.otf. See that entry's own comment for the full
    # reasoning (ttf-geist-mono shadowed by the OTF build; ttf-geist-mono-variable stays
    # undeclared, 0 registered faces). AUR-only, same as ui.geist.
    geist-mono = { arch = "otf-geist-mono"; nixpkgs = "geist-font"; aur = true; families = [ "Geist Mono" ]; };
    # Ships six independent widths (S/M/L, each plain and "DZ" -- dotted-zero); no single name is
    # THE family, so all six real ones are listed rather than picking one arbitrarily.
    meslo-nerd = {
      arch = "ttf-meslo-nerd"; nixpkgs = "nerd-fonts.meslo-lg";
      families = [ "MesloLGS Nerd Font" "MesloLGM Nerd Font" "MesloLGL Nerd Font" "MesloLGSDZ Nerd Font" "MesloLGMDZ Nerd Font" "MesloLGLDZ Nerd Font" ];
    };
    geist-mono-nerd = { arch = "otf-geist-mono-nerd"; nixpkgs = null; families = [ "GeistMono Nerd Font" ]; };
    # nixpkgs has no awesome-terminal-fonts. nerd-fonts.symbols-only is the equivalent by
    # PURPOSE -- a symbol/glyph-only font for shell prompts and status bars -- not the same
    # upstream project. Named here rather than left null because a host asking for prompt glyphs
    # gets what it actually wanted; if that substitution is wrong for you, set it to null.
    # `families` states the ARCH package's four real ones (FontAwesome/icomoon/octicons/
    # Pomodoro) -- the nixpkgs substitute's own family names were not independently verified, so
    # a NixOS host selecting this gets the packages but not this validation.
    awesome-terminal = { arch = "awesome-terminal-fonts"; nixpkgs = "nerd-fonts.symbols-only"; families = [ "FontAwesome" "icomoon" "octicons" "Pomodoro" ]; };
    source-code-pro = { arch = "adobe-source-code-pro-fonts"; nixpkgs = "source-code-pro"; families = [ "Source Code Pro" ]; };
    jetbrains-mono-nerd = { arch = "ttf-jetbrains-mono-nerd"; nixpkgs = "nerd-fonts.jetbrains-mono"; families = [ "JetBrainsMono Nerd Font" ]; };
    # families left [ ]: the family name carries the Font Awesome MAJOR VERSION ("Font Awesome 6
    # Free" vs "...7 Free"), which drifts on every upstream bump -- see this file's own header.
    font-awesome = { arch = "otf-font-awesome"; nixpkgs = "font-awesome"; };
  };

  # ── Document / print compatibility ──────────────────────────────────────────────────────────
  # liberation and corefonts are metric-compatible with the Microsoft families; gsfonts is what
  # ghostscript uses for PostScript, so a machine that prints or renders PDFs wants it even with
  # no desktop at all.
  document = {
    liberation = { arch = "ttf-liberation"; nixpkgs = "liberation_ttf"; families = [ "Liberation Sans" "Liberation Serif" "Liberation Mono" ]; };
    ms-core = {
      arch = "ttf-ms-fonts"; nixpkgs = "corefonts"; aur = true;
      # The 11 classic core TrueType fonts; names fixed since the 1996 release, safe to pin.
      families = [ "Andale Mono" "Arial" "Arial Black" "Comic Sans MS" "Courier New" "Georgia" "Impact" "Times New Roman" "Trebuchet MS" "Verdana" "Webdings" ];
    };
    # gyre, not "gsfonts": nixpkgs ships the URW base35 successors under that name, and they are
    # what ghostscript actually resolves the standard PostScript families to.
    gsfonts = {
      arch = "gsfonts"; nixpkgs = "gyre-fonts";
      # The URW base35 aliases Ghostscript has shipped under for decades.
      families = [ "Nimbus Sans" "Nimbus Sans Narrow" "Nimbus Roman" "Nimbus Mono PS" "URW Bookman" "URW Gothic" "C059" "P052" "D050000L" "Standard Symbols PS" "Z003" ];
    };
    dejavu = { arch = "ttf-dejavu"; nixpkgs = "dejavu_fonts"; families = [ "DejaVu Sans" "DejaVu Sans Mono" "DejaVu Serif" "DejaVu Math TeX Gyre" ]; };
    # families = [ "Archivo" ] only: the family also ships ~40 width/weight variants (Condensed,
    # Expanded, Black, ...) not enumerated here -- see this file's own header on scope.
    archivo = { arch = "otf-archivo"; nixpkgs = null; aur = true; families = [ "Archivo" ]; };
    source-serif = { arch = "adobe-source-serif-fonts"; nixpkgs = "source-serif"; families = [ "Source Serif 4" ]; };
    # No nixpkgs equivalent under any of bitstream-vera-fonts / vera-fonts / ttf-bitstream-vera.
    bitstream-vera = { arch = "ttf-bitstream-vera"; nixpkgs = null; families = [ "Bitstream Vera Sans" "Bitstream Vera Sans Mono" "Bitstream Vera Serif" ]; };
  };

  # ── Unicode coverage ────────────────────────────────────────────────────────────────────────
  # Not a style choice: without these, text outside your primary family's coverage renders as
  # tofu. Emoji in particular is a separate package on every distro.
  coverage = {
    # families left [ ]: covers 100+ scripts under names like "Noto Sans Devanagari" -- real, but
    # enumerating them buys nothing (nobody names a `defaults` value "Noto Sans Cuneiform").
    noto = { arch = "noto-fonts"; nixpkgs = "noto-fonts"; };
    noto-cjk = {
      arch = "noto-fonts-cjk"; nixpkgs = "noto-fonts-cjk-sans";
      families = [ "Noto Sans CJK HK" "Noto Sans CJK JP" "Noto Sans CJK KR" "Noto Sans CJK SC" "Noto Sans CJK TC" "Noto Sans Mono CJK HK" "Noto Sans Mono CJK JP" "Noto Sans Mono CJK KR" "Noto Sans Mono CJK SC" "Noto Sans Mono CJK TC" "Noto Serif CJK HK" "Noto Serif CJK JP" "Noto Serif CJK KR" "Noto Serif CJK SC" "Noto Serif CJK TC" ];
    };
    # nixpkgs renamed noto-fonts-emoji -> noto-fonts-color-emoji (throw-aliased 2025-10-27, caught
    # live 2026-08-03 building nixosConfigurations.nixnas against a post-rename nixpkgs pin: the
    # OLD name still exists as an attribute -- so `hasAttrByPath` alone says it "resolves" -- but
    # evaluating it throws instead of returning a package. See experiments/validate-nixpkgs-names.nix's
    # own header for the validator fix this forced.
    noto-emoji = { arch = "noto-fonts-emoji"; nixpkgs = "noto-fonts-color-emoji"; families = [ "Noto Color Emoji" ]; };
    # nixpkgs folded noto-fonts-extra INTO noto-fonts (same throw-alias rename, same date, same
    # discovery). The two catalogue keys now point at the same nixpkgs attribute on purpose --
    # Arch still ships them as two distinct packages (noto-fonts vs noto-fonts-extra), nixpkgs no
    # longer does, and this table's job is exactly to let that be true without either platform's
    # value being wrong.
    # families left [ ]: same "too many scripts to enumerate" reasoning as `noto` above.
    noto-extra = { arch = "noto-fonts-extra"; nixpkgs = "noto-fonts"; };
  };
}
