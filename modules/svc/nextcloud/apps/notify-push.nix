{ lib, config, ... }:
let
  cfg = config.nix-infra.svc.nextcloud.app.notify-push;
  cfg-nextcloud = config.nix-infra.svc.nextcloud;
in
{
  options.nix-infra.svc.nextcloud.app.notify-push = {
    enable = lib.mkEnableOption "nextcloud notify-push app";
  };

  # TODO: fix
  config = lib.mkIf cfg.enable {
    services.nextcloud.notify_push = {
      enable = true;
      nextcloudUrl = "https://${cfg-nextcloud.domain}";
    };

    services.caddy.virtualHosts."http://${cfg-nextcloud.domain}" = {
      extraConfig = lib.mkBefore ''
         handle_path /push/* {
           uri strip_prefix /push
           reverse_proxy unix//${config.services.nextcloud.notify_push.socketPath} {
             transport http {
        			keepalive 0
         		}
         		buffer_requests false
           }
         }
      '';
    };
  };
}
