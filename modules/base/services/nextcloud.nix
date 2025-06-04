{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.cfg;
in
{
  imports = [
    "${inputs.nextcloud-testumgebung}/nextcloud-extras.nix"
  ];

  options = {
    cfg.services.nextcloud = {
      enable = lib.mkEnableOption "nextcloud";
      domain = lib.mkOption {
        type = lib.types.str;
        default = "nextcloud.intranet.girl.pp.ua";
      };
    };
  };

  config = lib.mkIf cfg.services.nextcloud.enable {
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud31;

      webserver = "caddy";
      hostName = cfg.services.nextcloud.domain;
      https = false;

      # enable redis cache
      configureRedis = true;

      # database
      config.dbtype = "pgsql";
      database.createLocally = true;

      # options
      maxUploadSize = "16G";
      config = {
        adminuser = "root";
        adminpassFile = config.sops.secrets."nextcloud/adminpass".path;
      };
      settings = {
        enabledPreviewProviders = [
          "OC\\Preview\\BMP"
          "OC\\Preview\\GIF"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\OpenDocument"
          "OC\\Preview\\PNG"
          "OC\\Preview\\TXT"
          "OC\\Preview\\XBitmap"
          "OC\\Preview\\HEIC"
        ];
      };
    };

    sops.secrets."nextcloud/adminpass" = {
      mode = "0400";
      owner = "nextcloud";
    };
  };
}
