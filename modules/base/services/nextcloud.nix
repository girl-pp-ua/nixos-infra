{
  inputs,
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.cfg;
  idp = libx.idp {
    domain = cfg.services.kanidm.domain;
    client_id = cfg.services.nextcloud.clientID;
  };
  exiftool_12_70 = pkgs.exiftool.overrideAttrs (old: rec {
    version = "12.70";
    src = pkgs.fetchFromGitHub {
      owner = "exiftool";
      repo = "exiftool";
      tag = version;
      hash = "sha256-YMWYPI2SDi3s4KCpSNwovemS5MDj5W9ai0sOkvMa8Zg=";
    };
  });
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
        default = "cloud.girl.pp.ua";
      };
      intraDomain = lib.mkOption {
        type = lib.types.str;
        default = "nextcloud.intranet.girl.pp.ua";
      };
      clientID = lib.mkOption {
        type = lib.types.str;
        default = "nextcloud";
      };
    };
  };

  config = lib.mkIf cfg.services.nextcloud.enable {
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud31;

      # web server
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
        overwriteprotocol = "https";

        trusted_domains = [
          cfg.services.nextcloud.domain
          cfg.services.nextcloud.intraDomain
        ];

        "profile.enabled" = true;

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

        allow_user_to_change_display_name = false;
        lost_password_link = "disabled";

        # using only oidc, that already uses webauthn
        "auth.webauthn.enabled" = false;

        # oidc
        oidc_login_provider_url = idp.oidc_discovery_prefix;
        oidc_login_client_id = cfg.services.nextcloud.clientID;
        oidc_login_end_session_redirect = false; # no need
        oidc_login_button_text = "Log in with Girlcock™";
        oidc_login_hide_password_form = true;
        oidc_login_attributes = {
          id = "preferred_username";
          name = "name";
          mail = "email";
          # groups = "groups";
          # is_admin = "nextcloudadmin";
        };
        oidc_login_use_id_token = true;
        oidc_login_scope = "openid profile email groups";
        oidc_login_default_group = "oidc";
        oidc_create_groups = true;
        # oidc_login_update_avatar = true; # kanidm doesnt provide those
        oidc_login_disable_registration = false; # automatically create user accountss
        oidc_login_proxy_ldap = false;
        # oidc_login_password_authentication = true; # might be required for davx5
        oidc_login_code_challenge_method = "S256";

        "memories.readonly" = true;
        "memories.exiftool" = "${exiftool_12_70}/bin/exiftool";
        "memories.vod.disable" = false;
        "memories.vod.vaapi" = config.hardware.graphics.enable;
        "memories.vod.ffmpeg" = "${pkgs.ffmpeg}/bin/ffmpeg";
        "memories.vod.ffprobe" = "${pkgs.ffmpeg}/bin/ffprobe";

        preview_ffmpeg_path = "${pkgs.ffmpeg}/bin/ffmpeg";
      };
      secretFile = config.sops.secrets."nextcloud/secretFile".path;
      phpOptions = {
        "opcache.interned_strings_buffer" = "24";
      };
      extraOCCCommands =
        let
          occ = "${config.services.nextcloud.occ}/bin/nextcloud-occ";
        in
        ''
          ${occ} theming:config name "Girlcloud"
          ${occ} theming:config color "#F5C2E7"
          ${occ} theming:config primary_color "#F5C2E7"
        '';

      # apps
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          app_api
          contacts
          calendar
          tasks
          notes
          memories
          recognize
          # onlyoffice
          # whiteboard
          oidc_login
          ;
      };
      extraAppsEnable = true;
    };

    services.caddy.virtualHosts.${cfg.services.nextcloud.domain} = {
      serverAliases = [
        cfg.services.nextcloud.intraDomain
      ];
      extraConfig = ''
        import encode
      '';
    };

    users.users.nextcloud = {
      extraGroups = [
        "render"
        "video"
      ];
    };

    sops.secrets =
      let
        nextcloudSecret = {
          mode = "0400";
          owner = "nextcloud";
          group = "nextcloud";
        };
      in
      {
        "nextcloud/adminpass" = nextcloudSecret;
        "nextcloud/secretFile" = nextcloudSecret;
      };
  };
}
