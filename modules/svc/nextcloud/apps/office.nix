{ config, lib, ... }:
let
  cfg = config.nix-infra.svc.nextcloud.app.office;
  cfg-nextcloud = config.nix-infra.svc.nextcloud;
  cfg-collabora = config.nix-infra.svc.collabora;
in
{
  options.nix-infra.svc.nextcloud.app.office = {
    enable = lib.mkEnableOption "collabora office app" // {
      default = cfg-nextcloud.enable && cfg-collabora.enable;
    };
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          richdocuments
          ;
      };
      extraOCCCommands = ''
        occ config:app:set richdocuments wopi_url --value "http://[::1]:${cfg-collabora.port}"
        occ config:app:set richdocuments public_wopi_url --value "https://${cfg-collabora.domain}"
        occ config:app:set richdocuments wopi_allowlist --value "${
          lib.concatStringsSep "," [
            "127.0.0.1"
            "::1"
            "fd7a:115c:a1e0::/48" # tailscale
          ]
        }"
        occ richdocuments:activate-config
      '';
    };
  };
}
