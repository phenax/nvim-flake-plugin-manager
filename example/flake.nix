{
  inputs = {
    nvim-plugin-manager.url = "path:../";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    telescope-nvim = { url = "github:nvim-telescope/telescope.nvim"; flake = false; };
    plenary = { url = "github:nvim-lua/plenary.nvim"; flake = false; };
    leap = { url = "github:ggandor/leap.nvim"; flake = false; };
    bqn = { url = "github:mlochbaum/BQN"; flake = false; };
    material = { url = "github:kaicataldo/material.vim"; flake = false; };
  };

  outputs = sources@{ self, nixpkgs, flake-utils, nvim-plugin-manager, ... }:
    let
      plugins = {
        telescope-nvim = {
          requires = [ "plenary" ];
          configLua = ''
            vim.keymap.set('n', '<leader>f', ':Telescope find_files<cr>')
          '';
          # lazy.commands = [ ":Telescope" ];
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
            vim.o.background = "dark"
            vim.g.base16colorspace = 256

            vim.cmd 'colorscheme material'
          '';
        };
      };
    in
    flake-utils.lib.eachDefaultSystem (system: {
      packages.default = nvim-plugin-manager.lib.mkPlugins {
        inherit plugins sources system;
      };
    });
}
