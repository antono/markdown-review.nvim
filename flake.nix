{
  description = "Markdown Review - Neovim plugin with review comments";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    avi = {
      url = "github:antono/avi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      avi,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        markdown-review-plugin = pkgs.vimUtils.buildVimPlugin {
          name = "markdown-review.nvim";
          src = ./.;
        };

        # Extend avi's nixvim with markdown-review plugin and config
        nixvimLib = avi.inputs.nixvim.lib.${system};
        nixvim' = avi.inputs.nixvim.legacyPackages.${system};

        nixvimModule = {
          inherit pkgs;
          module = {
            imports = [ (import "${avi}/config") ];

            # Configure markdown-review settings
            globals.mdrv_auto_start = 0;
            globals.mdrv_auto_close = 1;
            globals.mdrv_enable_review = 1;
            globals.mdrv_filetypes = [ "markdown" ];
          };

          extraSpecialArgs = {
            inherit inputs self;
          };
        };

        # Build Neovim: avi (nixvim config) + markdown-review plugin
        # This combines avi's Neovim configuration with the markdown-review plugin,
        # creating a complete editor setup for markdown editing with review comments.
        nvimWithMarkdownReview = nixvim'.makeNixvimWithModule nixvimModule;
        nvimFinal = pkgs.wrapNeovim nvimWithMarkdownReview {
          plugins = [ markdown-review-plugin ];
        };

      in
      {
        packages.markdown-review = nvimFinal;
        packages.default = nvimFinal;

        devShells.default = pkgs.mkShell {
          name = "markdown-review-dev";
          description = "Development environment for markdown-review (Neovim + avi + plugin)";
          buildInputs = with pkgs; [
            # Neovim with avi configuration + markdown-review plugin
            # Use: nvim <file.md> to open in review mode
            nvimFinal

            # Development tools
            nodejs_20
            yarn
            typescript

            # Build tools
            pkg-config

            # Git & other utilities
            git
            gh
          ];

          shellHook = ''
            echo "╔═══════════════════════════════════════════════╗"
            echo "║  Markdown Review Development Environment      ║"
            echo "╚═══════════════════════════════════════════════╝"
            echo ""
            echo "Available tools:"
            echo "  • nvim        - Neovim with avi + markdown-review plugin"
            echo "  • yarn        - Package manager (for app development)"
            echo "  • node        - Node.js for backend/app"
            echo "  • typescript  - TypeScript compiler"
            echo ""
            echo "Try it:"
            echo "  nvim README.md"
            echo ""
          '';
        };
      }
    );
}
