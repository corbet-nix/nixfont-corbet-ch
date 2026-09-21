# nixfont

A small NixOS flake module that declares fonts as a shared concern — not owned by any single
downstream module, because fonts are consumed by four unrelated domains at once: the terminal
wants a nerd/monospace family, the desktop UI wants a sans font, documents want metric-compatible
families for printing, and PostScript rendering wants gsfonts. This module resolves each family
to the right package name on each platform and generates fontconfig aliases to make sans-serif,
serif, monospace, and emoji actually resolve to what the operator asked for.

The thesis in three sentences: a desktop module that owned fonts would force headless machines
rendering PDFs to pull in a desktop they do not have, just to get their gsfonts. A terminal module
that owned them would force UI clients to import the terminal stack. So fonts belong to nobody
and resolve on every machine. The useful part is not just a package list — it is generating the
actual fontconfig XML that makes the generic family names point to the families you selected.

## What nixfont is

A platform-neutral NixOS module that:

- **Selects fonts by group.** ui (interface fonts like Inter, Cantarell), mono (terminal fonts like
  Geist Mono Nerd, Meslo Nerd), document (metric-compatible families like Liberation and gsfonts
  for printing), and coverage (Unicode support fonts like Noto Sans).
- **Generates fontconfig aliases.** Takes four optional defaults — sans, serif, monospace, emoji —
  and emits actual fontconfig XML that teaches the system what `<family>sans-serif</family>` and
  friends actually resolve to. Without this, fontconfig picks alphabetically, and you get whatever
  it decides.
- **Resolves to platform-specific package names.** Via `lib/fonts.nix`, each family name maps to a
  pacman package (or AUR equivalent) and a nixpkgs attribute, or null where no equivalent exists.

It exists in three forms:

- `nixfont.nix`: the declarative policy, selection, and fontconfig emission.
- `modules/nixos.nix`: the NixOS backend, which installs via `fonts.packages`.
- `modules/arch.nix`: the Arch / system-manager backend, which publishes `nixfont.archPackages`
  and `nixfont.aurPackages` for the host's own reconciler to consume.

Every font is selected explicitly by the operator, never defaulted. An empty selection is a
legitimate answer — for a machine that never reads a visual document.

## What it explicitly does not own

- **Font rendering or hinting.** How Cairo or Freetype actually draws glyphs belongs to the
  system's fontconfig configuration and the font library's own algorithms, not here.
- **Fontconfig beyond the four basic aliases.** This module generates `<family>sans-serif</family>`
  precedence aliases and an emoji fallback. Deeper fontconfig tuning (antialiasing, hinting,
  substitution chains) belongs to nixarch's per-user fontconfig or systemd's fonts.conf, not to a
  package-list module.
- **Per-font tuning or variant selection.** nixfont declares families, not specific weights or
  optical sizes. If you need Geist Sans Light Weight 300, that is a user configuration question.
- **Terminal emulation or UI toolkit defaults.** Installing a monospace font does not declare
  which terminal will use it or which desktop environment gets which sans font by default —
  those are other modules' concerns.

## Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | Flake entry point: `nixosModules.default` (NixOS install), `systemManagerModules.default` (Arch publish), and `nixfont.nix` (the module). |
| `modules/` | Platform backends: `nixos.nix` and `arch.nix`. |
| `lib/fonts.nix` | The font catalogue: one entry per selectable family, with platform-specific package names. |
| `checks/` | Eval-time regression tests (`nix flake check`): no build, no VM -- evaluates the module and inspects what it renders. |

## Platform support

**NixOS:** Full. Selections resolve to nixpkgs attributes; the NixOS backend installs via
`fonts.packages`, and generates fontconfig XML to `/etc/fonts/conf.d/05-nixfont.conf`.

**Arch / CachyOS (via system-manager):** Publishes `nixfont.archPackages` and `nixfont.aurPackages`
for the host's reconciler to consume. Generates fontconfig XML as a plain file in `/etc/fonts/conf.d/`.
Cannot install packages itself.

## Related projects

Part of the same independently-usable NixOS module family: [nixdev](https://github.com/corbet-nix/nixdev-corbet-ch)
(operator tooling), [nixoffice](https://github.com/corbet-nix/nixoffice-corbet-ch) (documents half
of a workstation), [nixprint](https://github.com/corbet-nix/nixprint-corbet-ch) (printing declared),
and [nixram](https://github.com/corbet-nix/nixram-corbet-ch) (memory-pressure tuning).

## Licence

Outbound licence is `MIT OR Apache-2.0`. See `LICENSE-MIT` and `LICENSE-APACHE`; every source file carries `SPDX-License-Identifier: MIT OR Apache-2.0`.
