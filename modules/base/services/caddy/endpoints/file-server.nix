{ lib, config, ... }:
let
  cfg = config.cfg;
in
{
  options = {
    cfg.services.caddy.endpoints.file-server = {
      enable = lib.mkEnableOption "caddy file server endpoint";
      path = lib.mkOption {
        type = lib.types.path;
        default = "/data/files/public";
      };
    };
  };
  config = lib.mkIf cfg.services.caddy.endpoints.file-server.enable {
    services.caddy.virtualHosts = {
      "files.girl.pp.ua" = {
        serverAliases = [
          "files.beeg.pp.ua"
          "files-cf.beeg.pp.ua"
        ];
        extraConfig = ''
          import cors *
          import encode
          root * ${cfg.services.caddy.endpoints.file-server.path}
          file_server browse
        '';
      };
    };
  };
}
