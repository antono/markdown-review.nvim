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

        nvim-test = pkgs.writeShellScriptBin "nvim-test" ''
          set -e
          # Use PLUGIN_DIR from environment (set by nix develop) or current directory
          PLUGIN_DIR="''${PLUGIN_DIR:-.}"
          INIT_FILE=$(mktemp --suffix=.vim)
          trap "rm -f $INIT_FILE" EXIT

          cat > "$INIT_FILE" << 'VIMEOF'
          set runtimepath+=PLUGIN_PATH
          filetype plugin indent on
          VIMEOF

          sed -i "s|PLUGIN_PATH|$PLUGIN_DIR|g" "$INIT_FILE"

          FILE="''${1:-.}"
          if [[ -z "''${1:-}" ]]; then
            FILE="README.md"
          else
            shift || true
          fi

          exec ${pkgs.neovim}/bin/nvim -u "$INIT_FILE" "$FILE" "$@"
        '';

      in
      {
        packages.default = pkgs.neovim;
        packages.nvim-test = nvim-test;

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
            nvim-test
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
            echo "  nvim-test [file]"
            echo "  nvim-test README.md"
            echo ""
          '';
        };
      }
    );
}
