# SPDX-License-Identifier: MIT OR Apache-2.0
# Arch backend — publishes the package list and writes the fontconfig fragment.
#
# Installs nothing: on Arch that is the host reconciler's job. Wire it with
#   nixarch.packages.pacman = config.nixfont.archPackages;
{ config, lib, ... }:
{
  imports = [ ./nixfont.nix ];
  environment.etc."fonts/conf.d/50-nixfont.conf".text = config.nixfont.fontconfig;
  # Same recurrence guard the NixOS backend surfaces -- a `defaults.*` naming a font nothing
  # selected. See nixfont.nix's `unmatchedDefaults` for what counts as a match and what does not.
  warnings = config.nixfont.unmatchedDefaults;
}
