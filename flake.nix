{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {
    lib = {
      mkPlugins = { plugins, sources, system }:
        let
          pkgs = import nixpkgs { inherit system; };

          optional = prop: default: obj: with builtins; if hasAttr prop obj then getAttr prop obj else default;

          getPluginConf = with builtins; rec {
            conf = p: optional p { } plugins;
            configLua = p: optional "configLua" "" (conf p);
            rtp = p: "${sources."${p}"}/${optional "rtp" "" (conf p)}";
            requires = p: optional "requires" [ ] (conf p);

            isLazy = p: hasAttr "lazy" (conf p);
            lazyFileExts = p: optional "exts" [ ] (optional "lazy" { } (conf p));
            lazyCommands = p: optional "commands" [ ] (optional "lazy" { } (conf p));
          };

          allPluginNames = builtins.concatMap
            (p: [ p ] ++ getPluginConf.requires p)
            (builtins.attrNames plugins);

          loadPlugin = with builtins; p:
            let loaderCode = ''
              load_plugin_path(${toJSON (getPluginConf.rtp p)});
              ${getPluginConf.configLua p}
            '';
            in
            if length (getPluginConf.lazyFileExts p) > 0 then
              ''
                vim.api.nvim_create_autocmd({ "BufRead", "BufWinEnter", "BufNewFile" }, {
                  pattern = { ${concatStringsSep ", " (map toJSON (getPluginConf.lazyFileExts p))} },
                  callback = function() ${loaderCode} end,
                });
              ''
            else if length (getPluginConf.lazyCommands p) > 0 then
            # TODO: Support range commands
              toString
                (map
                  (cmd: ''
                    vim.api.nvim_create_user_command(${toJSON cmd}, function(opt)
                      vim.api.nvim_del_user_command(${toJSON cmd});
                      ${loaderCode}
                      vim.cmd(opt.name .. " " .. opt.args);
                    end, {})
                  '')
                  (getPluginConf.lazyCommands p))

            else loaderCode;

          # TODO: silent source ftdetect/**/*.vim after/ftdetect/**/*.vim
          luaFile = with builtins; toFile "load_plugins.lua" ''
            local loaded_plugins = {};
            local function load_plugin_path(path)
              if not vim.tbl_contains(loaded_plugins, path) then
                vim.opt.rtp:append(path)
                vim.opt.rtp:append(path .. 'after')

                table.insert(loaded_plugins, path)

                for _, plug in ipairs({ 'plugin/**/*.{vim,lua}', 'after/plugin/**/*.{vim,lua}' }) do
                  local plugin_files = vim.fn.glob(path .. plug, false, true)
                  if plugin_files and #plugin_files > 0 then
                    vim.cmd("silent source " .. table.concat(plugin_files, " "))
                  end
                end
              end
            end

            ${concatStringsSep "\n" (map loadPlugin allPluginNames)}
          '';
        in
        pkgs.stdenv.mkDerivation {
          name = "nvim-flake-plugin-manager";
          version = "0.0.0";

          phases = [ "buildPhase" "installPhase" ];

          buildPhase = ''
            mkdir -p $out;

            ln -s ${luaFile} $out/load_plugins.lua
          '';

          installPhase = '' '';
        };
    };
  };
}
