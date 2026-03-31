{ config, lib, ... }:
let
  cfg = config.polaris.services.caddy.endpoints.proxies;
  cfg' = config.polaris.services;
in
{
  options.polaris.services.caddy.endpoints.proxies = {
    enable = lib.mkEnableOption "caddy nc proxy endpoint";
  };
  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts = {
      ${cfg'.nextcloud.domain}.extraConfig = ''
        import encode
        reverse_proxy http://${cfg'.nextcloud.intraDomain}
      '';
      ${cfg'.paperless.domain}.extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://${cfg'.paperless.intraDomain}
      '';
      ${cfg'.immich.domain}.extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://${cfg'.immich.intraDomain}
      '';
      ${cfg'.forgejo.domain}.extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://${cfg'.forgejo.intraDomain}
      '';
    };
  };
}
