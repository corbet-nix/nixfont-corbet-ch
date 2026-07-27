# Arch backend — publishes the package list and writes the fontconfig fragment.
#
# Installs nothing: on Arch that is the host reconciler's job. Wire it with
#   nixarch.packages.pacman = config.nixfont.archPackages;
{ config, ... }:
{
  imports = [ ./nixfont.nix ];
  environment.etc."fonts/conf.d/50-nixfont.conf".text = config.nixfont.fontconfig;
}
