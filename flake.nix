{
  description = "Markdown Review - Neovim plugin with review comments";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      in
      {
        packages.default = pkgs.neovim;

        devShells.default = pkgs.mkShell {
          name = "markdown-review-dev";
          description = "Development environment for markdown-review plugin";
          buildInputs = with pkgs; [
            nodejs_22
            yarn
            typescript
            pkg-config
            git
            gh
          ];

          shellHook = ''
            export PLUGIN_DIR="${./.}"
            echo "╔═══════════════════════════════════════════════╗"
            echo "║  Markdown Review Development Environment      ║"
            echo "╚═══════════════════════════════════════════════╝"
            echo ""
            echo "Development tools:"
            echo "  • yarn        - Package manager (for app development)"
            echo "  • node        - Node.js for backend/app"
            echo "  • typescript  - TypeScript compiler"
            echo "  • git         - Version control"
            echo ""
            echo "To test with your existing Neovim, run:"
            echo "  nvim -u NONE +'set runtimepath+=$PLUGIN_DIR' README.md"
            echo ""
          '';
        };
      }
    );
}
