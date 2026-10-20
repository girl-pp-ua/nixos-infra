{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  inherit (config.polaris) hosts;
  cfg = config.polaris.services.monitoring.server;
  idp = libx.idp {
    domain = config.polaris.services.kanidm.domain;
    inherit (cfg) client_id;
  };

  fetchDashboard =
    {
      id,
      rev,
      hash,
      replace ? [ ],
    }:
    let
      src = pkgs.fetchurl {
        url = "https://grafana.com/api/dashboards/${toString id}/revisions/${toString rev}/download";
        inherit hash;
      };
    in
    if replace == [ ] then
      src
    else
      pkgs.runCommand "dashboard-${toString id}.json" { } ''
        substitute ${src} $out ${lib.escapeShellArgs (lib.concatMap (r: [ "--replace-fail" ] ++ r) replace)}
      '';

  dashboards = pkgs.linkFarm "grafana-dashboards" {
    "Hosts/node-exporter-full.json" = fetchDashboard {
      id = 1860;
      rev = 45;
      hash = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
    };
    "Hosts/fleet-overview.json" = fetchDashboard {
      id = 11074;
      rev = 9;
      hash = "sha256-iT9AKe6bPgeX662YndR7jfUW7U0Hjyje0tbY33u9EGU=";
      replace = [
        [
          "\${DS__VICTORIAMETRICS}"
          "VictoriaMetrics"
        ]
      ];
    };
    "Monitoring/victoriametrics.json" = fetchDashboard {
      id = 10229;
      rev = 60;
      hash = "sha256-DaucJDJektHb8h+mtRwkpbO97c5YIqh+KzXWK2dTPkM=";
      replace = [
        [
          # the official victoria* dashboards find their job by the "victoria-<product>-" version
          # prefix... which the nixpkgs builds don't use; so match the job name
          ''version=~\"victoria-metrics-.*\"''
          ''job=\"victoria-metrics\"''
        ]
      ];
    };
    "Monitoring/victorialogs.json" = fetchDashboard {
      id = 22084;
      rev = 12;
      hash = "sha256-7ZwB8CrnE8T5GXGY7rDlXFxkrJvxYclBBQbA2TwswUs=";
      replace = [
        [
          # the official victoria* dashboards find their job by the "victoria-<product>-" version
          # prefix... which the nixpkgs builds don't use; so match the job name
          ''version=~\"victoria-logs-.*\"''
          ''job=\"victorialogs\"''
        ]
      ];
    };
    "Logs/log-insights.json" = fetchDashboard {
      id = 24585;
      rev = 1;
      hash = "sha256-ok5td2ZNKtrSto9Lc9mazYTkhjIkMaUT6Fj1xpapieU=";
    };
  };
in
{
  options.polaris.services.monitoring.server = {
    enable = lib.mkEnableOption "monitoring server";
    port = lib.mkOption {
      type = lib.types.port;
      default = 16120;
    };
    victoriametricsPort = lib.mkOption {
      type = lib.types.port;
      default = 16121;
    };
    victorialogsPort = lib.mkOption {
      type = lib.types.port;
      default = 16123;
    };
    ingestPort = lib.mkOption {
      type = lib.types.port;
      default = 9428;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "grafana.lunya.cc";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "grafana.polaris";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "grafana";
    };
  };

  config = lib.mkIf cfg.enable {
    services.victoriametrics = {
      enable = true;
      listenAddress = "127.0.0.1:${toString cfg.victoriametricsPort}";
      retentionPeriod = "90d";
      extraOptions = [ "-selfScrapeInterval=60s" ];
      prometheusConfig = {
        global.scrape_interval = "60s";
        scrape_configs = [
          {
            job_name = "node";
            static_configs = lib.mapAttrsToList (name: host: {
              targets = [ "${host.internal.fqdn}:${toString config.services.prometheus.exporters.node.port}" ];
              labels = {
                host = name;
                instance = name;
              };
            }) hosts;
          }
          {
            job_name = "victorialogs";
            static_configs = [ { targets = [ "127.0.0.1:${toString cfg.victorialogsPort}" ]; } ];
          }
          {
            job_name = "grafana";
            static_configs = [ { targets = [ "127.0.0.1:${toString cfg.port}" ]; } ];
          }
        ];
      };
    };

    services.victorialogs = {
      enable = true;
      listenAddress = "127.0.0.1:${toString cfg.victorialogsPort}";
      extraOptions = [
        "-retentionPeriod=30d"
        "-retention.maxDiskSpaceUsageBytes=10GiB"
      ];
    };

    services.grafana = {
      enable = true;
      declarativePlugins = with pkgs.grafanaPlugins; [
        victoriametrics-logs-datasource
        grafana-metricsdrilldown-app
      ];
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = cfg.port;
          inherit (cfg) domain;
          root_url = "https://${cfg.domain}/";
          enable_gzip = true;
        };
        database = {
          type = "postgres";
          host = "/run/postgresql";
          name = "grafana";
          user = "grafana";
        };
        security = {
          secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
          cookie_secure = true;
          disable_gravatar = true;
          disable_initial_admin_creation = true;
        };
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
          feedback_links_enabled = false;
        };
        dashboards = {
          default_home_dashboard_path = "${dashboards}/Hosts/node-exporter-full.json";
          min_refresh_interval = "1m";
        };
        snapshots.external_enabled = false;
        public_dashboards.enabled = false;
        plugins = {
          preinstall_disabled = true;
          plugin_admin_enabled = false; # plugins are declarative
        };
        # cloud upsells and other bs
        cloud_migration.enabled = false;
        news.news_feed_enabled = false;
        help.enabled = false;
        feature_toggles = {
          feedbackButton = false;
          grafanaAdvisor = false;
          grafanaAssistantInProfilesDrilldown = false;
        };
        auth = {
          disable_login_form = true;
          oauth_auto_login = true;
        };
        "auth.basic".enabled = false;
        "auth.generic_oauth" = {
          enabled = true;
          name = "Kanidm";
          inherit (cfg) client_id;
          client_secret = "$__file{${config.sops.secrets."grafana/clientSecret".path}}";
          scopes = "openid profile email groups";
          auth_url = idp.user_auth;
          token_url = idp.token_endpoint;
          api_url = idp.oidc_user_info;
          use_pkce = true;
          use_refresh_token = true;
          allow_sign_up = true;
          login_attribute_path = "preferred_username";
          role_attribute_path = "contains(grafana_role[*], 'GrafanaAdmin') && 'GrafanaAdmin' || contains(grafana_role[*], 'Editor') && 'Editor' || 'Viewer'";
          role_attribute_strict = true;
          allow_assign_grafana_admin = true;
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "VictoriaMetrics";
            uid = "victoriametrics";
            type = "prometheus";
            url = "http://127.0.0.1:${toString cfg.victoriametricsPort}";
            isDefault = true;
            jsonData.timeInterval = "60s";
          }
          {
            name = "VictoriaLogs";
            uid = "victorialogs";
            type = "victoriametrics-logs-datasource";
            url = "http://127.0.0.1:${toString cfg.victorialogsPort}";
          }
        ];
        dashboards.settings.providers = [
          {
            name = "polaris";
            options = {
              path = dashboards;
              foldersFromFilesStructure = true;
            };
          }
        ];
      };
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "grafana" ];
      ensureUsers = [
        {
          name = "grafana";
          ensureDBOwnership = true;
        }
      ];
    };

    # log ingest for the agents
    networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
      cfg.ingestPort
    ];

    services.caddy.virtualHosts = {
      "http://:${toString cfg.ingestPort}".extraConfig = ''
        handle /insert/* {
          reverse_proxy localhost:${toString cfg.victorialogsPort}
        }
        respond 403
      '';
      ${cfg.domain}.extraConfig = ''
        import encode
        import norobot
        respond /metrics 404
        reverse_proxy localhost:${toString cfg.port}
      '';
      "http://${cfg.intraDomain}".extraConfig = ''
        redir https://${cfg.domain}{uri} temporary
      '';
    };

    sops.secrets =
      let
        grafanaSecret = {
          mode = "0400";
          owner = "grafana";
          group = "grafana";
        };
      in
      {
        "grafana/secret_key" = grafanaSecret;
        "grafana/clientSecret" = grafanaSecret;
      };
  };
}
