{ config, lib, host, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.healthcheck-endpoint = {
      enable = lib.mkEnableOption "caddy heathcheck endpoint" // {
        default = cfg.services.caddy.enable;
      };
    };
  };
  config = lib.mkIf cfg.services.healthcheck-endpoint.enable {
    services.caddy.virtualHosts = {
      "${host}.girl.pp.ua" = {
        serverAliases = [
          "ipv4.${host}.girl.pp.ua"
          "ipv6.${host}.girl.pp.ua"
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
  };
}