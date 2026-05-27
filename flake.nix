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
            echo "To test the plugin:"
            echo "  1. Add to your Neovim config:"
            echo "       vim.opt.runtimepath:append('$PLUGIN_DIR')"
            echo ""
            echo "  2. Or test with:"
            echo "       cat > /tmp/init.vim << 'VIMEOF'"
            echo "       set runtimepath+=$PLUGIN_DIR"
            echo "       filetype plugin on"
            echo "       VIMEOF"
            echo "       nvim -u /tmp/init.vim README.md"
            echo ""
          '';
        };
      }
    );
}
