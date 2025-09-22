{ config, lib, ... }:
let
  inherit (config) cfg;
in
{
  options = {
    cfg.services.caddy.endpoints.proxies = {
      enable = lib.mkEnableOption "caddy nc proxy endpoint";
    };
  };
  config = lib.mkIf cfg.services.caddy.endpoints.proxies.enable {
    services.caddy.virtualHosts = {
      ${cfg.services.nextcloud.domain}.extraConfig = ''
        import encode
        reverse_proxy http://${cfg.services.nextcloud.intraDomain}
      '';
      ${cfg.services.paperless.domain}.extraConfig = ''
        import encode
        reverse_proxy http://${cfg.services.paperless.intraDomain} {
            header_up Host {host}
        }
      '';
    };
  };
}
