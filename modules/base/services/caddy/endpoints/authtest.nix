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
    cfg.services.caddy.endpoints.authtest = {
      enable = lib.mkEnableOption "caddy authtest endpoint";
    };
  };
  config = lib.mkIf cfg.services.caddy.endpoints.authtest.enable {
    services.caddy.virtualHosts."authtest.girl.pp.ua".extraConfig = ''
      import oauth2_proxy
      respond "OK"
    '';
  };
}
