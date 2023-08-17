{
  description = "Make neovim plugins";

  outputs = { self }: {
    lib = {
      mkPlugins = import ./mk-plugins.nix;
    };
  };
}
