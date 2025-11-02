# Docs: https://devenv.sh/basics/
{ pkgs, ... }: {

  languages = {
    # Docs: https://devenv.sh/languages/
    nix.enable = true;
    rust = {
      enable = true; # https://github.com/cachix/devenv/blob/main/src/modules/languages/rust.nix
      # channel = "stable";
      # version = "1.90.0"; # Must match rust-toolchain.toml
      # targets = [ "wasm32-wasip1" "x86_64-unknown-linux-musl" ]; # Must match rust-toolchain.toml
      toolchainFile = ./rust-toolchain.toml;
    };
  };

  packages = with pkgs; [
    # Search for packages: https://search.nixos.org/packages?channel=unstable&query=cowsay
    # (note: this searches on unstable channel, be aware your nixpkgs flake input might be on a release channel)
    cargo-watch
    bacon
    protobuf # Required for building zellij
    openssl
    pkg-config
    # Additional build dependencies
    perl # Required by openssl-sys
  ];

  scripts = {
    # Docs: https://devenv.sh/scripts/
    #cr.exec = ''cargo run'';
  };

  difftastic.enable = true; # https://devenv.sh/integrations/difftastic/

  git-hooks.hooks = {
    # Docs: https://devenv.sh/pre-commit-hooks/
    # available pre-configured hooks: https://devenv.sh/reference/options/#pre-commithooks
    # adding hooks which are not included: https://github.com/cachix/pre-commit-hooks.nix/issues/31
    nil.enable = true; # nix lsp
    nixpkgs-fmt.enable = true; # nix formatting

    clippy.enable = true;
    #cargo-check.enable = true; ← if you don't want clippy
  };
}
