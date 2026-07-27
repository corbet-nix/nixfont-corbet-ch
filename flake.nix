{
  description = "nixfont — fonts as a shared concern: families, coverage, and the fontconfig defaults that make them actually resolve";

  # NO INPUTS. Options, a name table and generated fontconfig XML; `pkgs` comes from the consumer.

  outputs = { self }: {
    # Platform-neutral policy: selections, the resolved lists, and the fontconfig fragment.
    nixosModules.nixfont = ./modules/nixfont.nix;

    # NixOS backend — installs via fonts.packages.
    nixosModules.default = ./modules/nixos.nix;
    nixosModules.install = ./modules/nixos.nix;

    # Arch / system-manager backend — publishes `nixfont.archPackages` for the host's reconciler.
    systemManagerModules.nixfont = ./modules/arch.nix;
    systemManagerModules.default = ./modules/arch.nix;

    lib.catalogue = import ./lib/fonts.nix { };
  };
}
