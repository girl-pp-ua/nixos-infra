{ lib, config, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.file-server-endpoint = {
      enable = lib.mkEnableOption "caddy file server endpoint";
    };
  };
  config = lib.mkIf cfg.services.file-server-endpoint.enable {
    services.caddy.virtualHosts = {
      "files.girl.pp.ua" = {
        serverAliases = [
          "files.beeg.pp.ua"
          "files-cf.beeg.pp.ua"
        ];
        extraConfig = ''
          import cors *
          import encode
          root * /data/files/public
          file_server browse
        '';
      };
    };
  };
}