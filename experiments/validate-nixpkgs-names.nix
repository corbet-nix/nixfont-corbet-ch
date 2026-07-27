# Font package names drift badly between distros (ttf-liberation vs liberation_ttf, ttf-ms-fonts
# vs corefonts, noto-fonts-cjk vs noto-fonts-cjk-sans). This checks every non-null nixpkgs
# attribute in lib/fonts.nix actually resolves, including dotted paths like nerd-fonts.meslo-lg.
#
#   nix-instantiate --eval --strict experiments/validate-nixpkgs-names.nix -A missing   # => [ ]
{ nixpkgs ? <nixpkgs> }:
let
  pkgs = import nixpkgs { config.allowUnfree = true; };
  lib = pkgs.lib;
  cat = import ../lib/fonts.nix { };
  all = lib.flatten (map lib.attrValues (lib.attrValues cat));
  named = lib.filter (f: f.nixpkgs != null) all;
  resolves = f: lib.hasAttrByPath (lib.splitString "." f.nixpkgs) pkgs;
in
{
  checked = builtins.length named;
  missing = map (f: f.nixpkgs) (lib.filter (f: !(resolves f)) named);
}
