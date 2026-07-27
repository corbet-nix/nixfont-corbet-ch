#
# The font catalogue: one entry per family, named on each platform.
#
# `arch` is the pacman package, `nixpkgs` the attribute (or null where there is no equivalent).
# Fonts are unusually prone to name drift between distros -- `ttf-liberation` vs `liberation_ttf`,
# `ttf-ms-fonts` vs `corefonts` -- which is the whole reason this table exists rather than a bare
# list of package names in each consumer.
{ ... }:
{
  # ── UI / interface ──────────────────────────────────────────────────────────────────────────
  ui = {
    inter = { arch = "inter-font"; nixpkgs = "inter"; };
    cantarell = { arch = "cantarell-fonts"; nixpkgs = "cantarell-fonts"; };
    geist = { arch = "ttf-geist"; nixpkgs = "geist-font"; aur = true; };
    source-sans = { arch = "adobe-source-sans-fonts"; nixpkgs = "source-sans"; };
  };

  # ── Monospace / terminal ────────────────────────────────────────────────────────────────────
  mono = {
    geist-mono = { arch = "ttf-geist-mono"; nixpkgs = "geist-font"; aur = true; };
    meslo-nerd = { arch = "ttf-meslo-nerd"; nixpkgs = "nerd-fonts.meslo-lg"; };
    geist-mono-nerd = { arch = "otf-geist-mono-nerd"; nixpkgs = null; };
    # nixpkgs has no awesome-terminal-fonts. nerd-fonts.symbols-only is the equivalent by
    # PURPOSE -- a symbol/glyph-only font for shell prompts and status bars -- not the same
    # upstream project. Named here rather than left null because a host asking for prompt glyphs
    # gets what it actually wanted; if that substitution is wrong for you, set it to null.
    awesome-terminal = { arch = "awesome-terminal-fonts"; nixpkgs = "nerd-fonts.symbols-only"; };
    source-code-pro = { arch = "adobe-source-code-pro-fonts"; nixpkgs = "source-code-pro"; };
    jetbrains-mono-nerd = { arch = "ttf-jetbrains-mono-nerd"; nixpkgs = "nerd-fonts.jetbrains-mono"; };
    font-awesome = { arch = "otf-font-awesome"; nixpkgs = "font-awesome"; };
  };

  # ── Document / print compatibility ──────────────────────────────────────────────────────────
  # liberation and corefonts are metric-compatible with the Microsoft families; gsfonts is what
  # ghostscript uses for PostScript, so a machine that prints or renders PDFs wants it even with
  # no desktop at all.
  document = {
    liberation = { arch = "ttf-liberation"; nixpkgs = "liberation_ttf"; };
    ms-core = { arch = "ttf-ms-fonts"; nixpkgs = "corefonts"; aur = true; };
    # gyre, not "gsfonts": nixpkgs ships the URW base35 successors under that name, and they are
    # what ghostscript actually resolves the standard PostScript families to.
    gsfonts = { arch = "gsfonts"; nixpkgs = "gyre-fonts"; };
    dejavu = { arch = "ttf-dejavu"; nixpkgs = "dejavu_fonts"; };
    archivo = { arch = "otf-archivo"; nixpkgs = null; aur = true; };
    source-serif = { arch = "adobe-source-serif-fonts"; nixpkgs = "source-serif"; };
    # No nixpkgs equivalent under any of bitstream-vera-fonts / vera-fonts / ttf-bitstream-vera.
    bitstream-vera = { arch = "ttf-bitstream-vera"; nixpkgs = null; };
  };

  # ── Unicode coverage ────────────────────────────────────────────────────────────────────────
  # Not a style choice: without these, text outside your primary family's coverage renders as
  # tofu. Emoji in particular is a separate package on every distro.
  coverage = {
    noto = { arch = "noto-fonts"; nixpkgs = "noto-fonts"; };
    noto-cjk = { arch = "noto-fonts-cjk"; nixpkgs = "noto-fonts-cjk-sans"; };
    noto-emoji = { arch = "noto-fonts-emoji"; nixpkgs = "noto-fonts-emoji"; };
    noto-extra = { arch = "noto-fonts-extra"; nixpkgs = "noto-fonts-extra"; };
  };
}
