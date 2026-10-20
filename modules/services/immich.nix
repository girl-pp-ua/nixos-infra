{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.immich;

  idp = libx.idp {
    domain = config.polaris.services.kanidm.domain;
    inherit (cfg) client_id;
  };

  indexHtml = "${config.services.immich.package}/lib/node_modules/immich/build/www/index.html";
  indexHtmlPatched =
    let
      # if navigating to any admin page and not re-authenticated...
      # ...force reload so redirect properly takes over
      script = ''
        document.addEventListener('click', (e) => {
          const a = e.target.closest?.('a[href="/admin"], a[href^="/admin/"]');
          if (a) a.dataset.sveltekitReload = document.cookie.includes('_oauth2_proxy_pass=') ? 'off' : 'true';
        }, true);
      '';
    in
    pkgs.runCommand "immich-index.html" { } ''
      substitute ${indexHtml} $out \
        --replace-fail '</head>' ${lib.escapeShellArg "<script>${script}</script></head>"}
    '';
in
{
  options.polaris.services.immich = {
    enable = lib.mkEnableOption "immich";
    port = lib.mkOption {
      type = lib.types.int;
      default = 2283;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "photos.lunya.cc";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "immich";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "immich.polaris";
    };
  };

  config = lib.mkIf cfg.enable {
    services.immich = {
      enable = true;
      host = "localhost";
      inherit (cfg) port;
      accelerationDevices = [
        "/dev/dri/renderD128"
        "/dev/dri/card1"
      ];
      environment = {
        IMMICH_ALLOW_SETUP = "false";
        IMMICH_CONFIG_FILE = config.sops.templates."immich.json".path;
        IMMICH_TELEMETRY_INCLUDE = "all";
        IMMICH_API_METRICS_PORT = "8081";
        IMMICH_MICROSERVICES_METRICS_PORT = "8082";
        XDG_CACHE_HOME = "/var/cache/immich"; # (for mesa shader cache)
      };
      machine-learning.environment = {
        # keep models loaded
        MACHINE_LEARNING_MODEL_TTL = "0";
        MACHINE_LEARNING_PRELOAD__CLIP__TEXTUAL = "ViT-B-32__openai";
      };
    };
    polaris.services.monitoring.exports = {
      immich-api.port = 8081;
      immich-microservices.port = 8082;
    };

    systemd.services.immich-server.serviceConfig = {
      CacheDirectory = "immich";
      BindReadOnlyPaths = [ "${indexHtmlPatched}:${indexHtml}" ];
    };

    users.users.${config.services.immich.user}.extraGroups = [
      "video"
      "render"
    ];

    sops.secrets."immich/clientSecret" = { };
    sops.templates."immich.json" = {
      mode = "0400";
      owner = config.services.immich.user;
      group = config.services.immich.group;
      content = builtins.toJSON {
        server.externalDomain = "https://${cfg.domain}";
        newVersionCheck.enabled = false;
        passwordLogin.enabled = false;
        oauth = {
          enabled = true;
          autoLaunch = true;
          issuerUrl = idp.oidc_discovery;
          accountManagementUrl = "https://${config.polaris.services.kanidm.domain}/ui/profile";
          clientId = "immich";
          clientSecret = config.sops.placeholder."immich/clientSecret";
          signingAlgorithm = "ES256";
          # profileSigningAlgorithm = "ES256";
        };
        ffmpeg = {
          accel = "vaapi";
          # hw decode tonemaps hdr via hwmap=derive_device=opencl isn't supported on amd (rocm)
          accelDecode = false;
          realtime = {
            enabled = true;
            resolutions = [
              480
              720
              1080
            ];
            videoCodecs = [
              "h264"
              "hevc"
            ];
          };
        };
      };
    };

    services.caddy.virtualHosts."http://${cfg.intraDomain}" = {
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode

        import oauth2_proxy_handle

        @admin {
          path /admin /admin/*
          path /api/admin/*
          path /api/system-config /api/system-config/*
          path /api/system-metadata /api/system-metadata/*
          path /api/jobs /api/jobs/* /api/queues /api/queues/*
          path /api/libraries /api/libraries/*
          path /api/server/statistics /api/server/license
          not path /api/admin/maintenance/status /api/admin/maintenance/login
        }
        handle @admin {
          import oauth2_proxy_secure "immich_admin"
          reverse_proxy http://localhost:${toString config.services.immich.port}
        }

        reverse_proxy http://localhost:${toString config.services.immich.port}
      '';
    };
  };
}
