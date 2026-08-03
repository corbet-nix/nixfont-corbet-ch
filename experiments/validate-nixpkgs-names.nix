# Font package names drift badly between distros (ttf-liberation vs liberation_ttf, ttf-ms-fonts
# vs corefonts, noto-fonts-cjk vs noto-fonts-cjk-sans). This checks every non-null nixpkgs
# attribute in lib/fonts.nix actually resolves, including dotted paths like nerd-fonts.meslo-lg.
#
#   nix-instantiate --eval --strict experiments/validate-nixpkgs-names.nix -A missing   # => [ ]
#
# `resolves` FORCES the attribute, not just checks it exists. `hasAttrByPath` alone missed a real
# rename: nixpkgs converted `noto-fonts-emoji`/`noto-fonts-extra` to `throw "... renamed to ..."`
# on 2025-10-27, and the OLD name stayed present as an attribute (the throw IS the value) -- so
# the old existence-only check said "resolves" right up until modules/nixos.nix actually built
# `fonts.packages` and hit the throw for real (caught 2026-08-03 against a post-rename pin). A
# `mkOption`/attrset key can exist and still not be a package; only forcing the value tells you.
{ nixpkgs ? <nixpkgs> }:
let
  pkgs = import nixpkgs { config.allowUnfree = true; };
  lib = pkgs.lib;
  cat = import ../lib/fonts.nix { };
  all = lib.flatten (map lib.attrValues (lib.attrValues cat));
  named = lib.filter (f: f.nixpkgs != null) all;
  resolves = f:
    let path = lib.splitString "." f.nixpkgs; in
    lib.hasAttrByPath path pkgs
    && (builtins.tryEval (builtins.seq (lib.getAttrFromPath path pkgs) true)).success;
in
{
  checked = builtins.length named;
  missing = map (f: f.nixpkgs) (lib.filter (f: !(resolves f)) named);
}
