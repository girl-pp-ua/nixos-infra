{ lib, config, ... }:
let
  cfg = config.polaris.services.nextcloud.app.notify-push;
  cfg-nextcloud = config.polaris.services.nextcloud;
in
{
  options.polaris.services.nextcloud.app.notify-push = {
    enable = lib.mkEnableOption "nextcloud notify-push app" // {
      default = cfg-nextcloud.enable;
    };
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
          reverse_proxy unix/${config.services.nextcloud.notify_push.socketPath}
        }
      '';
    };
  };
}
