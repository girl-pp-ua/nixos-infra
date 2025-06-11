{ config, lib, ... }:
let
  inherit (config) cfg;
in
{
  options = {
    cfg.services.caddy.endpoints.nextcloud-proxy = {
      enable = lib.mkEnableOption "caddy nc proxy endpoint";
    };
  };
  config = lib.mkIf cfg.services.caddy.endpoints.nextcloud-proxy.enable {
    services.caddy.virtualHosts = {
      ${cfg.services.nextcloud.domain}.extraConfig = ''
        import encode
        reverse_proxy http://${cfg.services.nextcloud.intraDomain}
      '';
    };
  };
}
