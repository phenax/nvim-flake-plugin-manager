{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    telescope-nvim = { url = "github:nvim-telescope/telescope.nvim"; flake = false; };
    plenary = { url = "github:nvim-lua/plenary.nvim"; flake = false; };
    leap = { url = "github:ggandor/leap.nvim"; flake = false; };
    bqn = { url = "github:mlochbaum/BQN"; flake = false; };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    let
      pluginConfig = {
        telescope-nvim.requires = [ "plenary" ];
        leap = { };
        bqn = {
          rtp = "BQN/editors/vim";
          lazy = {
            ft = [ "*.bqn" ];
          };
        };
      };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { inherit system; };

          optional = prop: default: obj: with builtins; if hasAttr prop obj then getAttr prop obj else default;

          getPluginConf = rec {
            conf = p: optional p { } pluginConfig;
            rtp = p: "${inputs."${p}"}/${optional "rtp" "" (conf p)}";
            requires = p: optional "requires" [ ] (conf p);
          };

          allPlugins = builtins.concatMap
            (p: [ p ] ++ getPluginConf.requires p)
            (builtins.attrNames pluginConfig);

          toLoadPluginPath = with builtins; p: ''
            load_path_runtime("${getPluginConf.rtp p}");
          '';

          luaFile = with builtins; toFile "load_plugins.lua" "
            function load_path_runtime(path)
              vim.o.runtimepath = vim.o.runtimepath .. ',' .. vim.fn.expand(path)
            end

            ${toString (map toLoadPluginPath allPlugins)}
          ";
        in
        {
          packages.default =
            pkgs.stdenv.mkDerivation {
              name = "nvim-nix-plugin-manager";
              version = "0.0.0";

              phases = [ "buildPhase" "installPhase" ];

              buildPhase = ''
                mkdir -p $out;

                echo "${builtins.toString allPlugins}" > $out/log;

                ln -s ${luaFile} $out/load_plugins.lua
              '';

              installPhase = ''
            '';
            };
        });
}
