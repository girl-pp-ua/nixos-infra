{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.nix-infra.svc.projects.devlootbox;
in
{
  imports = [
    inputs.devlootbox.nixosModules.default
  ];
  options.nix-infra.svc.projects.devlootbox = {
    enable = lib.mkEnableOption "devlootbox";
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
        endpointUrl = "http://garage.nix-infra:3900";
        accessKeyIdFile = config.sops.secrets."garage/keys/devlootbox/key_id".path;
        secretAccessKeyFile = config.sops.secrets."garage/keys/devlootbox/secret".path;
      };
      discord = {
        tokenFile = config.sops.secrets."discord/devlootbox/production".path;
      };
      scrapeDoTokenFile = config.sops.secrets."scrape_do_token".path;

      svc-updater.enable = true;
      svc-media = {
        enable = true;
        settings.s3_bucket = "svc-media";
      };
      svc-discord = {
        enable = true;
        settings.media_cdn_url = "https://media-cdn.devlootbox.com/";
      };
    };

    sops.secrets = {
      "garage/keys/devlootbox/key_id" = { };
      "garage/keys/devlootbox/secret" = { };
      "discord/devlootbox/production" = { };
      "discord/devlootbox/development" = { };
      "scrape_do_token" = { };
    };
  };
}
