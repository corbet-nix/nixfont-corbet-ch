{
  description = "nixfont — fonts as a shared concern: families, coverage, and the fontconfig defaults that make them actually resolve";

  # ONE INPUT, TEST-ONLY. Every real output below (modules, `lib.catalogue`) still takes no
  # input at all -- `pkgs` comes from the consumer, exactly as before. `nixpkgs` exists solely to
  # give `checks`/`formatter` a `lib`/`pkgs` to evaluate against; a consumer composing
  # `nixosModules.default` or `systemManagerModules.default` never fetches it.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      # Platform-neutral policy: selections, the resolved lists, and the fontconfig fragment.
      nixosModules.nixfont = ./modules/nixfont.nix;

      # NixOS backend — installs via fonts.packages.
      nixosModules.default = ./modules/nixos.nix;
      nixosModules.install = ./modules/nixos.nix;

      # Arch / system-manager backend — publishes `nixfont.archPackages` for the host's reconciler.
      systemManagerModules.nixfont = ./modules/arch.nix;
      systemManagerModules.default = ./modules/arch.nix;

      lib.catalogue = import ./lib/fonts.nix { };

      # The eval-time regression net in ./checks -- see nixarch/nixram's own flake.nix comment on
      # why this must be wired into a real flake output: a suite that is written and committed but
      # unreachable from `nix flake check` reports success without evaluating a single assertion.
      checks = forAllSystems (system:
        import ./checks {
          pkgs = pkgsFor system;
          nixfontModule = self.nixosModules.nixfont;
        });

      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}
