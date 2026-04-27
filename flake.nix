{
  description = "Runtime CPU-feature probe for Lean 4";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.elan             # Lean 4 toolchain manager
            pkgs.qemu             # qemu-user for negative tests
          ];
        };
      }
    );
}
