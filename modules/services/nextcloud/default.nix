{
  inputs,
  config,
  pkgs,
  lib,
  libx,
  root,
  ...
}:
let
  inherit (config) cfg;
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
    ./apps/whiteboard-server.nix
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
        trusted_proxies = [
          "127.0.0.1"
          "::1"
          "2603:c020:800c:9c7f:0:fe:fe:2" # oci2
          "144.24.178.67" # oci2
        ];

        enable_previews = true;
        enabledPreviewProviders = [
          # Misc
          "OC\\Preview\\RIFF"

          # https://help.nextcloud.com/t/preview-settings-not-described-well/197952/9

          # No External Dependencies
          "OC\\Preview\\PNG"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\GIF"
          "OC\\Preview\\BMP"
          "OC\\Preview\\XBitmap"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\TXT"
          "OC\\Preview\\Krita"

          # ImageMagick Dependency
          "OC\\Preview\\SVG"
          "OC\\Preview\\TIFF"
          "OC\\Preview\\PDF"
          "OC\\Preview\\Illustrator"
          "OC\\Preview\\Photoshop"
          "OC\\Preview\\Postscript"
          "OC\\Preview\\Font"
          "OC\\Preview\\HEIC"
          "OC\\Preview\\TGA"
          "OC\\Preview\\SGI"

          # Office Dependency (preview_libreoffice_path)
          # (not needed with onlyoffice DocumentServer)
          # "OC\\Preview\\MSOfficeDoc"
          # "OC\\Preview\\MSOffice2003"
          # "OC\\Preview\\MSOffice2007"
          # "OC\\Preview\\OpenDocument"
          # "OC\\Preview\\StarOffice"
          # "OC\\Preview\\EMF"

          # AVConf/FFmpeg Dependency
          "OC\\Preview\\Movie"

          # Additional Providers
          "OC\\Preview\\WebP" # Requires PHP support for WebP images (php-gd)
        ];

        updatechecker = false;
        "profile.enabled" = true;
        token_auth_enforced = true; # disable username/password auth in 3rd party apps
        maintenance_window_start = 2; # 2 AM UTC ~= 3-4 AM Europe/Warsaw
        default_locale = "en_150"; # English (Europe)
        "simpleSignUpLink.shown" = false; # disable sign-up ad

        hide_login_form = true; # use ?direct=1 to bypass/login as root
        "auth.webauthn.enabled" = false; # using only oidc, that already uses webauthn
        allow_user_to_change_display_name = false; # does not work with oidc
        lost_password_link = "disabled";

        # oidc
        oidc_login_provider_url = idp.oidc_discovery_prefix;
        oidc_login_client_id = cfg.services.nextcloud.clientID;
        oidc_login_end_session_redirect = false; # no need
        oidc_login_button_text = "Log in with ${cfg.services.kanidm.domain}";
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

        # memories
        "memories.readonly" = true;
        "memories.exiftool" = "${exiftool_12_70}/bin/exiftool";
        # transcoding doesn't seem to work :<
        # probably needs go-vod
        "memories.vod.disable" = true;
        # "memories.vod.disable" = false;
        "memories.vod.vaapi" = config.hardware.graphics.enable;
        "memories.vod.ffmpeg" = "${pkgs.ffmpeg}/bin/ffmpeg";
        "memories.vod.ffprobe" = "${pkgs.ffmpeg}/bin/ffprobe";

        preview_ffmpeg_path = "${pkgs.ffmpeg}/bin/ffmpeg";
        # broken: cannot create directory '/run/user/989': Permission denied
        # preview_libreoffice_path = "${pkgs.libreoffice}/bin/libreoffice";
      };
      secretFile = config.sops.secrets."nextcloud/secretFile".path;
      extraOCCCommands =
        let
          occ = "${config.services.nextcloud.occ}/bin/nextcloud-occ";
        in
        ''
          ${occ} theming:config name "Girlcloud"
          ${occ} theming:config color "#F5C2E7"
          ${occ} theming:config primary_color "#F5C2E7"
          ${occ} theming:config background "${root}/assets/wallpapers/yuri3.jpg"
        '';

      # php stuff
      phpOptions = {
        "opcache.interned_strings_buffer" = "48";
      };
      phpExtraExtensions =
        all: with all; [
          imagick
          gd
        ];

      # apps
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          app_api
          calendar
          tasks
          contacts
          notes
          deck
          forms
          news
          maps
          music
          recognize
          memories
          # onlyoffice
          # richdocuments
          oidc_login
          previewgenerator
          ;
      };
      extraAppsEnable = true;
    };

    services.caddy.virtualHosts."http://${cfg.services.nextcloud.domain}" = {
      serverAliases = [
        cfg.services.nextcloud.domain
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
