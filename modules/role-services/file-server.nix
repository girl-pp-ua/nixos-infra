{ ... }: {
  services.caddy.virtualHosts = {
    "files.girl.pp.ua" = {
      serverAliases = [
        "files.beeg.pp.ua"
        "files-cf.beeg.pp.ua"
      ];
      extraConfig = ''
        import cors *
        import encode
        root * /data/files/public
        file_server browse
      '';
    };
  };
}