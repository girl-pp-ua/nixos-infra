{ config, lib, ... }:
let
  cfg = config.nix-infra.svc.nextcloud.app.whiteboard;
  cfg-nextcloud = config.nix-infra.svc.nextcloud;
in
{
  options.nix-infra.svc.nextcloud.app.whiteboard = {
    enable = lib.mkEnableOption "nextcloud whiteboard app" // {
      default = cfg-nextcloud.enable;
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 16031;
    };
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud-whiteboard-server = {
      enable = true;
      settings = {
        PORT = "${toString cfg.port}";
        NEXTCLOUD_URL = "https://${cfg-nextcloud.domain}";
      };
      secrets = [
        config.sops.templates."nextcloud_whiteboard_secretFile".path
      ];
    };

    services.nextcloud = {
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps) whiteboard;
      };
      extraOCCCommands = ''
        occ config:app:set whiteboard collabBackendUrl --value="https://${cfg-nextcloud.domain}/whiteboard/"
        occ config:app:set whiteboard jwt_secret_key --value="$(cat ${
          config.sops.secrets."nextcloud/whiteboard/jwt_secret_key".path
        })"
      '';
    };

    services.caddy.virtualHosts."http://${cfg-nextcloud.domain}" = {
      extraConfig = lib.mkBefore ''
        handle_path /whiteboard/* {
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        }
      '';
    };

    sops.secrets."nextcloud/whiteboard/jwt_secret_key" = { };
    sops.templates."nextcloud_whiteboard_secretFile" = {
      content = "JWT_SECRET_KEY = ${config.sops.placeholder."nextcloud/whiteboard/jwt_secret_key"}";
    };
  };
}
