{
  config,
  lib,
  host,
  ...
}:
let
  cfg = config.cfg;
in
{
  options = {
    cfg.services.caddy.endpoints.healthcheck = {
      enable = lib.mkEnableOption "caddy heathcheck endpoint";
    };
  };
  config = lib.mkIf cfg.services.caddy.endpoints.healthcheck.enable {
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
      "http://oci-loadbalancer.girl.pp.ua" = {
        serverAliases = [
          "http://ipv4.oci-loadbalancer.girl.pp.ua"
          "http://ipv6.oci-loadbalancer.girl.pp.ua"
        ];
        extraConfig = ''
          import cors *
          respond "OK ${host}"
        '';
      };
    };
  };
}
