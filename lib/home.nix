args@{ config, lib, pkgs, ... }:

let
  my._root = ../.;
  my.modules = modules: map (module : import (my._root + "/modules/${module}/home.nix") (lib.recursiveUpdate args {inherit my;})) modules;

  my.home = config.home.homeDirectory;
  my.config = config.xdg.configHome;
  my.nixcfg = "${my.home}/.nixcfg";
  my.mkAbsolute = path: "${my.nixcfg}/${path}";

  my.mkPathEnv = path: ''PATH="$PATH:${path}"'';

  #####
  #{ `home.file` utilities

  # Make out of store symlink for non-nix configs.
  # This makes it possible to hot-reload configurations.
  # https://github.com/nix-community/home-manager/issues/676
  my.mkLink = path: { source = config.lib.file.mkOutOfStoreSymlink (my.mkAbsolute path); };

  # Helpers for linking `~/.config/${target}` to `source`.
  # target: String, source: Path
  my.mkConfig = target: source: { "${my.config}/${target}" = my.mkLink source; };

  # Make shell scripts that will be called on shell login.
  my.mkGlue = {
    _mk =
      stage: name: fn:
      fn "${my.config}/sh-glue/${stage}/${name}";
    _mk' = stage: {
      # Direct file text
      text =
        name: text:
        my.mkGlue._mk stage name (x: {
          "${x}".text = text;
        });
      # Nix base symlink, for usage with nix packages
      source =
        name: source:
        my.mkGlue._mk stage name (x: {
          "${x}".source = source;
        });
      # Out of store symlink, for non-nix configs
      link =
        name: link:
        my.mkGlue._mk stage name (x: {
          "${x}" = my.mkLink link;
        });
    };

    head = my.mkGlue._mk' "head";
    tail = my.mkGlue._mk' "tail";

    init = stage: ''
      for f in ${my.config}/sh-glue/${stage}/*; do
          source $f
      done
    '';
  };
in
my
