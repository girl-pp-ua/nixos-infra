{ config, lib, ... }:
let
  inherit (config) cfg;
in
{
  options = {
    cfg.services.nextcloud.whiteboard-app = {
      enable = lib.mkEnableOption "nextcloud whiteboard app" // {
        default = cfg.services.nextcloud.enable;
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 16031;
      };
    };
  };

  config = lib.mkIf cfg.services.nextcloud.whiteboard-app.enable {
    services.nextcloud-whiteboard-server = {
      enable = true;
      settings = {
        PORT = "${toString cfg.services.nextcloud.whiteboard-app.port}";
        NEXTCLOUD_URL = "https://${cfg.services.nextcloud.domain}";
      };
      secrets = [
        config.sops.secrets."nextcloud/whiteboard/secretFile".path
      ];
    };

    services.nextcloud = {
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps) whiteboard;
      };
      extraOCCCommands =
        let
          occ = "${config.services.nextcloud.occ}/bin/nextcloud-occ";
        in
        ''
          ${occ} config:app:set whiteboard collabBackendUrl --value="https://${cfg.services.nextcloud.domain}/whiteboard/"
          ${occ} config:app:set whiteboard jwt_secret_key --value="$(cat ${
            config.sops.secrets."nextcloud/whiteboard/jwt_secret_key".path
          })"
        '';
    };

    services.caddy.virtualHosts."http://${cfg.services.nextcloud.domain}" = {
      extraConfig = lib.mkBefore ''
        handle_path /whiteboard/* {
          reverse_proxy http://127.0.0.1:${toString cfg.services.nextcloud.whiteboard-app.port}
        }
      '';
    };

    sops.secrets."nextcloud/whiteboard/secretFile" = { };
    sops.secrets."nextcloud/whiteboard/jwt_secret_key" = { };
  };
}
