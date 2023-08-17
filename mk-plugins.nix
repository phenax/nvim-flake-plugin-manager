{ pkgs
, plugins
, sources
, installPath
, modulePath
}:
with builtins;
let
  optional = prop: default: obj: if hasAttr prop obj then getAttr prop obj else default;

  getPluginConf = rec {
    conf = p: optional p { } plugins;
    configLua = p: optional "configLua" "" (conf p);
    configModule = p: optional "configModule" "" (conf p);
    rtp = p: "${sources.${p}}/${optional "rtp" "" (conf p)}";
    dependencies = p: optional "dependencies" [ ] (conf p);
    isLazy = p: hasAttr "lazy" (conf p);
    lazyFileExts = p: optional "exts" [ ] (optional "lazy" { } (conf p));
    lazyCommands = p: optional "commands" [ ] (optional "lazy" { } (conf p));
  };

  allPluginNames = builtins.concatMap
    (p: [ p ] ++ getPluginConf.dependencies p)
    (builtins.attrNames plugins);

  loadPlugin = p:
    let loaderCode = ''
      scope(function()
        nf_loadPlugin(${toJSON (getPluginConf.rtp p)});
        ${getPluginConf.configLua p}
        ${if getPluginConf.configModule p == "" then "" else ''
          local configModule = require(${toJSON (getPluginConf.configModule p)})
          configModule.setup()
        ''}
      end)
    '';
    in
    if length (getPluginConf.lazyFileExts p) > 0 then
      ''
        scope(function()
          local group = vim.api.nvim_create_augroup(${toJSON "nvim_flake_lazy__${p}"}, { clear = true });
          vim.api.nvim_create_autocmd({ "BufRead", "BufWinEnter", "BufNewFile" }, {
            group = group,
            pattern = { ${concatStringsSep ", " (map toJSON (getPluginConf.lazyFileExts p))} },
            callback = function()
              vim.api.nvim_del_augroup_by_id(group);
              ${loaderCode}
            end,
          });
        end);
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

  # TODO: source ftdetect
  luaFile = toFile "load_plugins.lua" ''
    local pluginInstallPath = vim.fn.expand(${toJSON installPath});
    vim.opt.rtp:append(pluginInstallPath .. "/*");
    vim.opt.rtp:append(pluginInstallPath .. "/*/after");
    vim.opt.rtp:append(${toJSON modulePath});

    local loaded_plugins = {};
    local function scope(fn) fn() end;
    local function nf_loadPlugin(path)
      if not vim.tbl_contains(loaded_plugins, path) then
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

  # installCommand = pkgs.runCommandLocal "nvim-nix-install-command" { nativeBuildInputs = [ pkgs.xorg.lndir ]; } '' '';
in
pkgs.stdenv.mkDerivation {
  name = "nvim-flake-plugin-manager";
  version = "0.0.0";

  src = ./.;

  phases = [ "buildPhase" "installPhase" ];

  buildInputs = [ ];

  buildPhase = ''
    mkdir -p $out;

    ${toString (map (p: "ln -s ${sources.${p}} $out/${p};") allPluginNames)}

    ln -s ${luaFile} $out/load_plugins.lua
  '';

  installPhase = '' '';
}
