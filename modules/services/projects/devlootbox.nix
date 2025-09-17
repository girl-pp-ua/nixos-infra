{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.cfg.services.projects.devlootbox;
in
{
  imports = [
    inputs.devlootbox.nixosModules.default
  ];
  options = {
    cfg.services.projects.devlootbox = {
      enable = lib.mkEnableOption "devlootbox";
    };
  };
  config = lib.mkIf cfg.enable {
    services.devlootbox-bot = {
      enable = true;

      database = {
        setupPostgres = true;
        sqlxMigrations.enable = true;
      };

      aws = {
        region = "garage";
        endpointUrl = "http://localhost:3900";
        accessKeyIdFile = config.sops.secrets."garage/keys/devlootbox/key_id".path;
        secretAccessKeyFile = config.sops.secrets."garage/keys/devlootbox/secret".path;
      };
      discord = {
        tokenFile = config.sops.secrets."discord/devlootbox/production".path;
      };

      svc-updater.enable = true;
      svc-media = {
        enable = true;
        settings.s3_bucket = "svc-media";
      };
      svc-discord = {
        enable = true;
        settings.media_cdn_url = "https://cdn.devlootbox.com/";
      };
    };

    sops.secrets = {
      "garage/keys/devlootbox/key_id" = { };
      "garage/keys/devlootbox/secret" = { };
      "discord/devlootbox/production" = { };
      "discord/devlootbox/development" = { };
    };
  };
}
