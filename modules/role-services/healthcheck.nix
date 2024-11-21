{ host, ... }: {
  services.caddy.virtualHosts = {
    "${host}.beeg.pp.ua" = {
      serverAliases = [
        "${host}.girl.pp.ua"
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