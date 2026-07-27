# NixOS backend — installs via fonts.packages and writes the same fontconfig fragment.
{ config, lib, pkgs, ... }:
let
  cat = import ../lib/fonts.nix { };
  all = lib.flatten (map lib.attrValues (lib.attrValues cat));
  wanted = lib.filter (f: f.nixpkgs != null && (lib.hasAttrByPath (lib.splitString "." f.nixpkgs) pkgs)) all;
  chosen = lib.filter (f: lib.elem f.arch config.nixfont.archPackages) wanted;
in
{
  imports = [ ./nixfont.nix ];
  config = {
    fonts.packages = map (f: lib.getAttrFromPath (lib.splitString "." f.nixpkgs) pkgs) chosen;
    environment.etc."fonts/conf.d/50-nixfont.conf".text = config.nixfont.fontconfig;
    warnings = lib.optional (config.nixfont.unavailableOnNixos != [ ])
      "nixfont: no nixpkgs equivalent for: ${lib.concatStringsSep ", " config.nixfont.unavailableOnNixos}";
  };
}
