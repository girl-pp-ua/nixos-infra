{ lib, config, ... }:
let
  inherit (config) cfg;
in
{
  options = {
    cfg.services.caddy.endpoints.webdav = {
      enable = lib.mkEnableOption "caddy webdav endpoint";
    };
  };
  config = lib.mkIf cfg.services.caddy.endpoints.webdav.enable {
    services.caddy.virtualHosts = {
      "webdav.girl.pp.ua" = {
        serverAliases = [
          "legacy.webdav.girl.pp.ua"
        ];
        extraConfig = ''
          route {
            basic_auth {
              ${cfg.secrets.webdav.username} ${cfg.secrets.webdav.hashed_password}
            }
            root * /data/files
            @get method GET
            file_server @get browse
            webdav {
              root /data/files
            }
            import encode
          }
        '';
      };
    };
  };
}
