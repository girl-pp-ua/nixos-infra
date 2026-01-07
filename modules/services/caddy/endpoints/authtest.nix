{
  config,
  lib,
  ...
}:
let
  cfg = config.polaris.services.caddy.endpoints.authtest;
in
{
  options.polaris.services.caddy.endpoints.authtest = {
    enable = lib.mkEnableOption "caddy authtest endpoint";
  };
  config = lib.mkIf cfg.enable {
    polaris.services.oauth2_proxy.enable = true;
    services.caddy.virtualHosts."authtest.girl.pp.ua".extraConfig = ''
      import oauth2_proxy "authtest_access"
      respond "OK"
    '';
  };
}
