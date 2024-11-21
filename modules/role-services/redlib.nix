{ ... }: rec {
  services.redlib = {
    enable = true;
    address = "127.0.0.1";
    port = 16001;
  };
  services.caddy.virtualHosts = {
    "redlib.beeg.pp.ua" = {
      serverAliases = [
        "redlib-cf.beeg.pp.ua"
      ];
      extraConfig = ''
        reverse_proxy localhost:${builtins.toString services.redlib.port}
      '';
    };
  };
}