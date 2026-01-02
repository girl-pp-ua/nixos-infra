{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.nix-infra.svc.nextcloud;
in
{
  imports = [
    "${inputs.nextcloud-testumgebung}/nextcloud-extras.nix"
    ./apps/whiteboard-server.nix
    ./apps/notify-push.nix
    ./apps/memories.nix
    ./apps/richdocuments.nix
    ./theming.nix
    ./oidc.nix
    ./previews.nix
  ];

  options.nix-infra.svc.nextcloud = {
    enable = lib.mkEnableOption "nextcloud";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "cloud.girl.pp.ua";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud.nix-infra";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud32;

      # web server
      webserver = "caddy";
      hostName = cfg.domain;
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
        "overwrite.cli.url" = "https://${cfg.domain}";
        overwriteprotocol = "https";

        trusted_domains = [
          cfg.domain
          cfg.intraDomain
        ];
        trusted_proxies = [
          # TODO dont hardcode this

          # localhost
          "127.0.0.1"
          "::1"

          # tailscale
          "fd7a:115c:a1e0::/48"
          "100.64.0.0/16"

          # oci primary-vcn
          "2603:c020:800c:9c00::/56"
          "132.226.204.218" # oci1
          "144.24.178.67" # oci2

          # oci2
          "10.0.0.254" # local v4
          "144.24.178.67" # global v4
        ];

        updatechecker = false;
        "profile.enabled" = true;
        token_auth_enforced = true; # disable username/password auth in 3rd party apps
        maintenance_window_start = 2; # 2 AM UTC ~= 3-4 AM Europe/Warsaw
        default_locale = "en_150"; # English (Europe)
        "simpleSignUpLink.shown" = false; # disable sign-up ad
      };

      # php stuff
      phpOptions = {
        "opcache.interned_strings_buffer" = "64";
      };
      phpExtraExtensions =
        ext: with ext; [
          imagick
          gd
        ];

      extraOCCCommands = lib.mkBefore ''
        tmpdir=$(mktemp -d)
        ln -s "${config.services.nextcloud.occ}/bin/nextcloud-occ" "$tmpdir/occ"
        export PATH="$tmpdir:$PATH"
      '';

      # apps
      extraAppsEnable = true;
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          calendar
          tasks
          contacts
          notes
          deck
          forms
          tables
          news
          music
          recognize
          impersonate
          end_to_end_encryption
          integration_paperless
          dav_push
          qownnotesapi
          ;
      };
    };

    services.caddy.virtualHosts."http://${cfg.domain}" = {
      serverAliases = [
        "http://${cfg.intraDomain}"
      ];
      extraConfig = lib.mkOrder 100 ''
        import encode
      '';
    };

    # bend nextcloud domain to it's tailscale ip
    # required for the trusted proxy chain to be valid when reaching ourselves over public domain
    # which is needded by notify_push
    networking.hosts = {
      # TODO dont hardcode this
      "fd7a:115c:a1e0::2501:5a59" = [ cfg.domain ];
    };

    users.users.nextcloud = {
      extraGroups = [
        "render"
        "video"
        "audio"
      ];
    };

    sops =
      let
        nextcloudSecret = {
          mode = "0400";
          owner = "nextcloud";
          group = "nextcloud";
        };
      in
      {
        secrets."nextcloud/adminpass" = nextcloudSecret;
        secrets."nextcloud/clientSecret" = { };
      };
  };
}
