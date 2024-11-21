{ ... }: rec {
  services.redlib = {
    enable = true;
    address = "127.0.0.1";
    port = 16001;
  };
  services.caddy.virtualHosts = {
    "redlib.girl.pp.ua" = {
      serverAliases = [
        "redlib-cf.girl.pp.ua"
      ];
      extraConfig = ''
        reverse_proxy localhost:${builtins.toString services.redlib.port}
      '';
    };
  };
}