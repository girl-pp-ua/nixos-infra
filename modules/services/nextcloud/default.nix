{
  inputs,
  config,
  pkgs,
  lib,
  system,
  ...
}:
let
  cfg = config.polaris.services.nextcloud;
  nc4nix = pkgs.callPackage inputs.nc4nix { };
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

  options.polaris.services.nextcloud = {
    enable = lib.mkEnableOption "nextcloud";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "cloud.lunya.cc";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud.polaris";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud";
    };

    package = lib.mkPackageOption pkgs "nextcloud33" { };
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      enable = true;
      package = cfg.package;

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
        trusted_proxies = config.polaris.trustedNetworks;

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
        "opcache.memory_consumption" = "256";
        "opcache.save_comments" = "1";
        "opcache.jit" = "1255";
        "opcache.jit_buffer_size" = "8M";
        # https://docs.nextcloud.com/server/23/admin_manual/installation/server_tuning.html#enable-php-opcache
        "opcache.revalidate_freq" = "60";
        "opcache.validate_timestamps" = "0";
        # "opcache.optimization_level" =
        "pm.max_children" = "192";
        "pm.start_servers" = "48";
        "pm.min_spare_servers" = "48";
        "pm.max_spare_servers" = "144";
      };
      phpExtraExtensions =
        ext: with ext; [
          imagick
          gd
        ];

      extraOCCCommands = lib.mkBefore (
        ''
          tmpdir=$(mktemp -d)
          ln -s "${config.services.nextcloud.occ}/bin/nextcloud-occ" "$tmpdir/occ"
          export PATH="$tmpdir:$PATH"
        ''
        + ''
          occ config:app:set bookmarks privacy.enableScraping --type=boolean --value=true
          occ config:app:set recognize node_binary --type=string --value="${pkgs.nodejs}/bin/node"
          occ config:app:set recognize ffmpeg_binary --type=string --value="${pkgs.ffmpeg}/bin/ffmpeg"
          occ config:app:set recognize nice_binary --type=string --value="${pkgs.coreutils}/bin/nice"
        ''
      );

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
          bookmarks
          groupfolders
          impersonate
          end_to_end_encryption
          integration_paperless
          dav_push
          qownnotesapi
          files_retention
          guests
          ;

        inherit
          (inputs.nixpkgs-but-with-nextcloud-recognize-omg-im-so-fucking-annoyed-by-this-shit.legacyPackages.${system}.nextcloud33.packages.apps
          )
          recognize
          ;

        inherit (nc4nix.nextcloud-33)
          integration_immich
          files_lock
          sketch_picker
          markdownreadme
          transfer
          ;

        # https://apps.nextcloud.com/apps/integration_google
        # automatically migrate your Google calendars, contacts, and files into Nextcloud
        # TODO: needs oauth setup
        #
        # also:
        # # integration_giphy
        # markdownreadme
        # iframewidget
        # external
        # externalportal
        # linkboard # seems interesting
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
      # TODO don't hardcode this; this should be the internal ip of the host running (outermost) reverse proxy
      ${config.polaris.hosts.astra.internal.ipv6} = [ cfg.domain ];
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
