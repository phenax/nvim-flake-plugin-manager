{ pkgs, pluginConfig, inputs }:
let
  optional = prop: default: obj: with builtins; if hasAttr prop obj then getAttr prop obj else default;

  getPluginConf = with builtins; rec {
    conf = p: optional p { } pluginConfig;
    config = p: optional "config" "" (conf p);
    rtp = p: "${inputs."${p}"}/${optional "rtp" "" (conf p)}";
    requires = p: optional "requires" [ ] (conf p);
    isLazy = p: hasAttr "lazy" (conf p);
    lazyFileExts = p: optional "extensions" [ ] (optional "lazy" { } (conf p));
  };

  allPlugins = builtins.concatMap
    (p: [ p ] ++ getPluginConf.requires p)
    (builtins.attrNames pluginConfig);

  loadPlugin = with builtins; p:
    let loaderCode = ''
      load_plugin_path(${toJSON (getPluginConf.rtp p)});
      ${getPluginConf.config p}
    '';
    in
    if getPluginConf.isLazy p then
      ''
        vim.api.nvim_create_autocmd({ "BufRead", "BufWinEnter", "BufNewFile" }, {
          pattern = { ${concatStringsSep ", " (map toJSON (getPluginConf.lazyFileExts p))} },
          callback = function() ${loaderCode} end,
        });
      ''
    else loaderCode;

  # TODO: silent source ftdetect/**/*.vim after/ftdetect/**/*.vim
  luaFile = with builtins; toFile "load_plugins.lua" (concatStringsSep "\n" [
    ''
      local loaded_plugins = {};
      local function load_plugin_path(path)
        if not vim.tbl_contains(loaded_plugins, path) then
          vim.opt.rtp:append(path)
          vim.opt.rtp:append(path .. 'after')

          table.insert(loaded_plugins, path)

          for _, plug in ipairs({ 'plugin/**/*.{vim,lua}', 'after/plugin/**/*.{vim,lua}' }) do
            local plugin_files = vim.fn.glob(path .. plug, false, true)
            if plugin_files then
              vim.cmd("silent source " .. table.concat(plugin_files, " "))
            end
          end
        end
      end
    ''
    (concatStringsSep "\n" (map loadPlugin allPlugins))
  ]);
in
pkgs.stdenv.mkDerivation
{
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
}
