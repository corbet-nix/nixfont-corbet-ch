# NixOS backend — installs via fonts.packages and writes the same fontconfig fragment.
{ config, lib, pkgs, ... }:
let
  # Filter `nixfont.selected` directly -- NOT `archPackages` (that list is deliberately Arch's
  # own pacman/AUR split, e.g. `geist` is withheld from it because it needs an AUR helper on
  # Arch). NixOS has no AUR at all, so cross-referencing archPackages here used to drop every
  # AUR-flagged-on-Arch font from `fonts.packages` even when nixpkgs carries it as an ordinary
  # attribute -- an Arch packaging distinction silently deciding what a NixOS host gets to
  # install. `selected` is the platform-neutral "what did this host actually ask for" instead.
  named = lib.filter (f: f.nixpkgs != null) config.nixfont.selected;

  # `hasAttrByPath` only proves the ATTRIBUTE exists, not that it is a usable package: nixpkgs
  # converts a renamed package to `<oldName> = throw "renamed to ...";`, which keeps the key
  # present and only breaks when the value is actually forced -- exactly what building
  # `fonts.packages` does (caught live 2026-08-03: `noto-fonts-emoji`/`noto-fonts-extra` had both
  # been throw-aliased upstream since 2025-10-27, and `lib/fonts.nix` still pointed at the old
  # names). `tryEval` turns that from a hard failure of the WHOLE system evaluation into a skip +
  # a warning -- lib/fonts.nix is a data table, edited far less carefully than code, and a single
  # stale mapping in it should not be able to take a host down. Sibling of `unavailableOnNixos`
  # ("no mapping was ever given"): this is "a mapping was given but nixpkgs has since moved it".
  evaluated = map
    (f: { inherit f; try = builtins.tryEval (builtins.seq (lib.getAttrFromPath (lib.splitString "." f.nixpkgs) pkgs) true); })
    named;
  installable = map (r: r.f) (lib.filter (r: r.try.success) evaluated);
  staleMappings = map
    (r: "nixfont: nixpkgs attribute \"${r.f.nixpkgs}\" (catalogue arch name \"${r.f.arch}\") no longer resolves -- lib/fonts.nix's mapping is stale, most likely a nixpkgs rename")
    (lib.filter (r: !r.try.success) evaluated);
in
{
  imports = [ ./nixfont.nix ];
  config = {
    fonts.packages = lib.unique (map (f: lib.getAttrFromPath (lib.splitString "." f.nixpkgs) pkgs) installable);

    # NOT environment.etc."fonts/conf.d/50-nixfont.conf" -- that was this backend's ORIGINAL
    # approach and it is broken: NixOS's own fonts.fontconfig module (nixos/modules/config/
    # fonts/fontconfig.nix) sets `environment.etc.fonts.source` to a single whole-tree symlink at
    # `/etc/fonts`, built by merging `fonts.fontconfig.confPackages` via `pkgs.buildEnv`. A
    # SIBLING `environment.etc."fonts/conf.d/*"` declaration collides with that whole-directory
    # symlink instead of layering into it -- the etc activation script fails with a bare
    # `Permission denied` trying to place a file under a path that is itself already a symlink to
    # an immutable store tree. This never surfaced before because nothing had composed this
    # backend onto a real nixosConfiguration until 2026-08-03 (three desktops, one font set); it
    # would have broken the very first NixOS host to use it. `confPackages` is the mechanism
    # fontconfig.nix itself documents for exactly this: contribute a package containing
    # `etc/fonts/conf.d/*.conf`, and the module's own `buildEnv` merges it in correctly.
    fonts.fontconfig.confPackages = [
      (pkgs.writeTextDir "etc/fonts/conf.d/50-nixfont.conf" config.nixfont.fontconfig)
    ];

    warnings =
      lib.optional (config.nixfont.unavailableOnNixos != [ ])
        "nixfont: no nixpkgs equivalent for: ${lib.concatStringsSep ", " config.nixfont.unavailableOnNixos}"
      ++ staleMappings
      ++ config.nixfont.unmatchedDefaults;
  };
}
