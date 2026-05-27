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

        # Build neovim with markdown-review plugin included
        nvimWithMarkdownReview = nixvim'.makeNixvimWithModule nixvimModule;
        nvimFinal = pkgs.wrapNeovim nvimWithMarkdownReview {
          plugins = [ markdown-review-plugin ];
        };

      in
      {
        packages.default = nvimFinal;
        packages.markdown-review = nvimFinal;

        devShells.default = pkgs.mkShell {
          name = "markdown-review-dev";
          buildInputs = with pkgs; [
            # Neovim with avi + markdown-review
            nvimFinal

            # Development tools
            nodejs_20
            yarn
            typescript

            # Build tools
            pkg-config

            # Git & other utils
            git
            gh
          ];

          shellHook = ''
            echo "Markdown Review development environment loaded"
            echo "nvim = Neovim with avi + markdown-review plugin"
            echo "yarn = Install dependencies"
          '';
        };
      }
    );
}
