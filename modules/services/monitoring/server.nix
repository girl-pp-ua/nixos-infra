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
              labels.host = name;
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
        };
        snapshots.external_enabled = false;
        public_dashboards.enabled = false;
        news.news_feed_enabled = false;
        plugins.preinstall_disabled = true;
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
            folder = "Polaris";
            options.path = pkgs.linkFarm "grafana-dashboards" {
              "node-exporter-full.json" = pkgs.fetchurl {
                url = "https://grafana.com/api/dashboards/1860/revisions/45/download";
                hash = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
              };
              "victoriametrics.json" = pkgs.fetchurl {
                url = "https://grafana.com/api/dashboards/10229/revisions/60/download";
                hash = "sha256-DaucJDJektHb8h+mtRwkpbO97c5YIqh+KzXWK2dTPkM=";
              };
              "victorialogs.json" = pkgs.fetchurl {
                url = "https://grafana.com/api/dashboards/22084/revisions/12/download";
                hash = "sha256-7ZwB8CrnE8T5GXGY7rDlXFxkrJvxYclBBQbA2TwswUs=";
              };
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
