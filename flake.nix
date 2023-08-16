{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    telescope-nvim = { url = "github:nvim-telescope/telescope.nvim"; flake = false; };
    plenary = { url = "github:nvim-lua/plenary.nvim"; flake = false; };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    let
      pluginConfig = {
        telescope-nvim = {
          requires = [ "plenary" ];
          lazy = false;
        };
      };

      loadPlugins = builtins.map (p: inputs."${p}");
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          packages.default = pkgs.stdenv.mkDerivation {
            name = "nvim-nix-plugin-manager";
            version = "0.0.0";

            src = inputs.telescope-nvim;

            unpackPhase = "";

            buildPhase = ''
              mkdir -p $out;
              ln -s ${inputs.telescope-nvim} $out/telescope-nvim;
              ln -s ${inputs.plenary} $out/plenary;
            '';

            installPhase = "ls $out";
          };
        });
}
