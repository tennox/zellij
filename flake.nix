{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # or use /nixos-unstable to get latest packages, but maybe less caching
    systems.url = "github:nix-systems/default"; # (i) allows overriding systems easily, see https://github.com/nix-systems/nix-systems#consumer-usage
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay"; # TODO: replace with fenix?
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
  };

  outputs = inputs@{ self, systems, flake-parts, nixpkgs, rust-overlay, crane, devenv, ... }: (
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = (import systems);
      imports = [
        inputs.devenv.flakeModule
      ];

      # perSystem docs: https://flake.parts/module-arguments.html#persystem-module-parameters
      perSystem = { config, self', inputs', pkgs, system, ... }: (
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              rust-overlay.overlays.default
            ];
          };
          # docs: https://github.com/oxalica/rust-overlay?tab=readme-ov-file#cheat-sheet-common-usage-of-rust-bin
          rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

          # Custom filter to include assets alongside Cargo sources
          assetFilter = path: type:
            (craneLib.filterCargoSources path type) ||
            # Include assets directory and its contents  
            (pkgs.lib.hasInfix "/assets/" path) ||
            (pkgs.lib.hasSuffix ".wasm" path) ||
            (pkgs.lib.hasSuffix ".kdl" path) ||
            (pkgs.lib.hasSuffix ".proto" path) ||
            (pkgs.lib.hasSuffix ".bash" path) ||
            (pkgs.lib.hasSuffix ".fish" path) ||
            (pkgs.lib.hasSuffix ".zsh" path);

          commonArgs = {
            # https://crane.dev/getting-started.html
            src = pkgs.lib.cleanSourceWith {
              src = craneLib.path ./.;
              filter = assetFilter;
            };
            strictDeps = true;

            # Follow nixpkgs approach - disable vendored dependencies
            OPENSSL_NO_VENDOR = "1";

            # Remove vendored_curl feature to use system libcurl (like nixpkgs does)
            postPatch = ''
              substituteInPlace Cargo.toml \
                --replace-fail ', "vendored_curl"' ""
            '';

            # Build for native target
            buildInputs = with pkgs; [
              openssl
              curl
            ];

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];
          };
          my-crate = craneLib.buildPackage (commonArgs // { });
        in
        {
          _module.args.pkgs = pkgs; # apply overlay - https://flake.parts/overlays#consuming-an-overlay
          # Per-system attributes can be defined here. The self' and inputs'
          # module parameters provide easy access to attributes of the same
          # system.
          checks = {
            inherit my-crate;
          };

          packages.default = my-crate;

          devenv.shells.default = {
            imports = [
              ./devenv.nix
            ];
            languages.rust.toolchain = rustToolchain;
            # Useful packages for nix, so I put them here instead of devenv.nix
            packages = with pkgs; [
              nixpkgs-fmt
              nil
            ];
          };
        }
      );
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

      };
    }
  );

  nixConfig = {
    extra-substituters = [
      "https://devenv.cachix.org" # https://devenv.sh/binary-caching/
      "https://nix-community.cachix.org" # for fenix
    ];
    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };


}
