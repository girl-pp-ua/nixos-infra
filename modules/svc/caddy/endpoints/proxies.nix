{ config, lib, ... }:
let
  cfg = config.nix-infra.svc.caddy.endpoints.proxies;
  cfg-nextcloud = config.nix-infra.svc.nextcloud;
  cfg-paperless = config.nix-infra.svc.paperless;
  cfg-immich = config.nix-infra.svc.immich;
  cfg-collabora = config.nix-infra.svc.collabora;
in
{
  options.nix-infra.svc.caddy.endpoints.proxies = {
    enable = lib.mkEnableOption "caddy nc proxy endpoint";
  };
  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts = {
      ${cfg-nextcloud.domain}.extraConfig = ''
        import encode
        reverse_proxy http://${cfg-nextcloud.intraDomain}
      '';
      ${cfg-paperless.domain}.extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://${cfg-paperless.intraDomain}
      '';
      ${cfg-immich.domain}.extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://${cfg-immich.intraDomain}
      '';
    };
  };
}
