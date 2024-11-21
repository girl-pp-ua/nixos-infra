{ host, ... }: {
  services.caddy.virtualHosts = {
    "${host}.girl.pp.ua" = {
      serverAliases = [
        "${host}.beeg.pp.ua"
        "ipv4.${host}.beeg.pp.ua"
        "ipv6.${host}.beeg.pp.ua"
      ];
      extraConfig = ''
        import cors *
        respond "OK"
      '';
    };
  };
}