{ host, ... }: {
  services.caddy.virtualHosts = {
    "${host}.beeg.pp.ua" = {
      serverAliases = [
        "ipv4.${host}.beeg.pp.ua"
        "ipv6.${host}.beeg.pp.ua"
      ];
      extraConfig = ''
        respond "OK"
      '';
    };
  };
}