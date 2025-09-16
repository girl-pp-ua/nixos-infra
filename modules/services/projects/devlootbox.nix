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
        endpointUrl = "http://localhost:9000";
        accessKeyIdFile = config.sops.secrets."garage/keys/devlootbox/id".path;
        secretAccessKeyFile = config.sops.secrets."garage/keys/devlootbox/secret".path;
      };
      discord = {
        tokenFile = config.sops.secrets."devlootbox/discord_token/production".path;
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
      "garage/keys/devlootbox/id" = { };
      "garage/keys/devlootbox/secret" = { };
      "devlootbox/discord_token/production" = { };
      "devlootbox/discord_token/development" = { };
    };
  };
}
