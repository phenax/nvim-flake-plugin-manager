{
  description = "Example neovim plugin configurations";

  inputs = {
    nvim-plugin-manager.url = "../";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Neovim plugin sources
    telescope = { url = "github:nvim-telescope/telescope.nvim"; flake = false; };
    plenary = { url = "github:nvim-lua/plenary.nvim"; flake = false; };
    leap = { url = "github:ggandor/leap.nvim"; flake = false; };
    bqn = { url = "github:mlochbaum/BQN"; flake = false; };
    material = { url = "github:kaicataldo/material.vim"; flake = false; };
  };

  outputs = sources@{ self, nixpkgs, flake-utils, home-manager, nvim-plugin-manager, ... }:
    let
      plugins = {
        telescope = {
          dependencies = [ "plenary" ];
          configModule = "_telescope";
        };
        leap = { };
        bqn = {
          rtp = "BQN/editors/vim";
          lazy.exts = [ "*.bqn" ];
        };
        material = {
          configLua = ''
            vim.g.material_terminal_italics = 1
            vim.g.material_theme_style = 'ocean'
            vim.cmd 'colorscheme material'
          '';
        };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = nvim-plugin-manager.lib.mkPlugins {
          inherit plugins sources pkgs;
          modulePath = ./.;
        };
      });
}
