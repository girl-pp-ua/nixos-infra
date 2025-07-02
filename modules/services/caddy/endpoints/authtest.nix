{
  config,
  lib,
  host,
  ...
}:
let
  inherit (config) cfg;
in
{
  options = {
    cfg.services.caddy.endpoints.authtest = {
      enable = lib.mkEnableOption "caddy authtest endpoint";
    };
  };
  config = lib.mkIf cfg.services.caddy.endpoints.authtest.enable {
    cfg.services.oauth2_proxy.enable = true;
    services.caddy.virtualHosts."authtest.girl.pp.ua".extraConfig = ''
      import oauth2_proxy "authtest_access"
      respond "OK"
    '';
  };
}
