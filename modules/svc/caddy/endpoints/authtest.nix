{
  config,
  lib,
  ...
}:
let
  cfg = config.nix-infra.svc.caddy.endpoints.authtest;
in
{
  options.nix-infra.svc.caddy.endpoints.authtest = {
    enable = lib.mkEnableOption "caddy authtest endpoint";
  };
  config = lib.mkIf cfg.enable {
    nix-infra.svc.oauth2_proxy.enable = true;
    services.caddy.virtualHosts."authtest.girl.pp.ua".extraConfig = ''
      import oauth2_proxy "authtest_access"
      respond "OK"
    '';
  };
}
