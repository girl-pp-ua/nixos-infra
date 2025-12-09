{ lib, config, ... }:
let
  cfg = config.nix-infra.svc.caddy.endpoints.file-server;
in
{
  options.nix-infra.svc.caddy.endpoints.file-server = {
    enable = lib.mkEnableOption "caddy file server endpoint";
    path = lib.mkOption {
      type = lib.types.path;
      default = "/data/files/public";
    };
  };
  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts = {
      "files.girl.pp.ua" = {
        serverAliases = [
          "files.beeg.pp.ua"
          "files-cf.beeg.pp.ua"
        ];
        extraConfig = ''
          import cors *
          import encode
          import norobot
          root * ${cfg.path}
          file_server browse
        '';
      };
    };
  };
}
