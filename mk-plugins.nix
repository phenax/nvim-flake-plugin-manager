{ pkgs
, plugins
, sources
, modulePath
}:
with builtins;
let
  prop = key: default: obj: if hasAttr key obj then getAttr key obj else default;

  getPluginConf = rec {
    conf = p: prop p { } plugins;
    configLua = p: prop "configLua" "" (conf p);
    configModule = p: prop "configModule" "" (conf p);
    rtp = p: "${sources.${p}}/${prop "rtp" "" (conf p)}";
    dependencies = p: prop "dependencies" [ ] (conf p);
    isLazy = p: hasAttr "lazy" (conf p);
    lazyFileExts = p: prop "exts" [ ] (prop "lazy" { } (conf p));
    lazyCommands = p: prop "commands" [ ] (prop "lazy" { } (conf p));
  };

  allPluginNames = builtins.concatMap
    (p: getPluginConf.dependencies p ++ [ p ])
    (builtins.attrNames plugins);

  loadPlugin = p:
    let loaderCode = ''
      nf_loadPlugin(${toJSON p}, ${toJSON (getPluginConf.rtp p)}, function ()
        ${getPluginConf.configLua p}

        ${if getPluginConf.configModule p == "" then "" else ''
          local configModule = require(${toJSON (getPluginConf.configModule p)})
          configModule.setup()
          return configModule
        ''}
      end);
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

  luaFile = toFile "load_plugins.lua" ''
    vim.opt.rtp:append(${toJSON modulePath});

    local loadedPlugins = {};
    local function scope(fn) fn() end;
    local function nf_loadPlugin(name, path, configure)
      if loadedPlugins[name] == nil then
        loadedPlugins[name] = { path = path };
        vim.opt.rtp:append(path);
        vim.opt.rtp:append(path .. "after");

        for _, plug in ipairs({ 'plugin/**/*.{vim,lua}', 'after/plugin/**/*.{vim,lua}' }) do
          local plugin_files = vim.fn.glob(path .. plug, false, true)
          if plugin_files and #plugin_files > 0 then
            vim.cmd("silent source " .. table.concat(plugin_files, " "))
          end
        end

        if configure ~= nil then
          loadedPlugins[name].module = configure()
        end
      end
    end

    ${concatStringsSep "\n" (map loadPlugin allPluginNames)}
  '';

  luaTestFile = toFile "test.lua" ''
    -- TODO: Add some basic assertions?
    print(vim.inspect(vim.o.rtp))

    vim.cmd [[q]]
  '';
in
pkgs.stdenv.mkDerivation {
  name = "nvim-flake-plugin-manager";
  version = "0.0.0";

  doCheck = true;
  phases = [ "installPhase" "checkPhase" ];

  buildInputs = [ pkgs.neovim ];

  installPhase = ''
    mkdir -p $out;

    ${toString (map (p: "ln -s ${sources.${p}} $out/${p};") allPluginNames)}

    ln -s ${luaFile} $out/load_plugins.lua
  '';

  checkPhase = ''
    ls $out
    nvim --headless --clean -c "luafile $out/load_plugins.lua" -c 'luafile ${luaTestFile}'
  '';
}
