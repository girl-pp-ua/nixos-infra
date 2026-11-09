{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.polaris.services.projects.devlootbox;
in
{
  imports = [
    inputs.devlootbox.nixosModules.default
  ];
  options.polaris.services.projects.devlootbox = {
    enable = lib.mkEnableOption "devlootbox";
  };
  config = lib.mkIf cfg.enable {
    services.devlootbox-bot = {
      enable = true;

      database = {
        setupPostgres = true;
        sqlxMigrations = {
          enable = true;
          # XXX: remove once nixpkgs fixes it (NixOS/nixpkgs#570940)
          # cargoSetupHook now forces system sqlite, but sqlx-cli doesn't have it in buildInputs
          package = pkgs.sqlx-cli.overrideAttrs (old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.sqlite ];
          });
        };
      };

      aws = {
        region = "garage";
        # endpointUrl = "http://garage.polaris:3900";
        endpointUrl = "http://${config.polaris.hosts.oci1.internal.ipv4}:3900";
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
        settings.media_cdn_url = "https://media-cdn.devlootbox.on.lunya.cc/";
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
