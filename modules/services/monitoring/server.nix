{
  config,
  pkgs,
  lib,
  libx,
  inputs,
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
      id ? null,
      rev ? null,
      url ? "https://grafana.com/api/dashboards/${toString id}/revisions/${toString rev}/download",
      hash,
      replace ? [ ],
    }:
    let
      src = pkgs.fetchurl { inherit url hash; };
    in
    if replace == [ ] then
      src
    else
      pkgs.runCommand "dashboard.json" { } ''
        substitute ${src} $out ${lib.escapeShellArgs (lib.concatMap (r: [ "--replace-fail" ] ++ r) replace)}
      '';

  atticGrantsSql = pkgs.writeText "grafana-attic-grants.sql" ''
    GRANT CONNECT ON DATABASE atticd TO grafana;
    GRANT USAGE ON SCHEMA public TO grafana;
    GRANT SELECT ON object, nar, chunk TO grafana;
    GRANT SELECT (id, name, is_public, store_dir, priority, upstream_cache_key_names, created_at, deleted_at, retention_period) ON cache TO grafana;
  '';

  atticDashboard =
    let
      ds = {
        type = "grafana-postgresql-datasource";
        uid = "attic";
      };
      query = format: rawSql: {
        datasource = ds;
        inherit format rawSql;
        rawQuery = true;
        editorMode = "code";
        refId = "A";
      };
      stat = x: title: unit: rawSql: {
        type = "stat";
        inherit title;
        datasource = ds;
        gridPos = {
          inherit x;
          y = 0;
          w = 6;
          h = 4;
        };
        targets = [ (query "table" rawSql) ];
        fieldConfig.defaults.unit = unit;
        options.reduceOptions.calcs = [ "lastNotNull" ];
      };
      table = x: title: rawSql: {
        type = "table";
        inherit title;
        datasource = ds;
        gridPos = {
          inherit x;
          y = 12;
          w = 12;
          h = 12;
        };
        targets = [ (query "table" rawSql) ];
        fieldConfig.overrides = [
          {
            matcher = {
              id = "byName";
              options = "size";
            };
            properties = [
              {
                id = "unit";
                value = "bytes";
              }
            ];
          }
        ];
      };
      shortPath = "regexp_replace(o.store_path, '^/nix/store/[a-z0-9]{32}-', '')";
    in
    pkgs.writeText "attic.json" (
      builtins.toJSON {
        uid = "attic";
        title = "Attic";
        tags = [ "attic" ];
        schemaVersion = 39;
        time = {
          from = "now-30d";
          to = "now";
        };
        panels = [
          (stat 0 "Store paths" "short" "SELECT count(*) FROM object")
          (stat 6 "Uncompressed" "bytes" "SELECT sum(nar_size) FROM nar")
          (stat 12 "Stored" "bytes" "SELECT sum(file_size) FROM chunk")
          (stat 18 "Stored / uncompressed" "percentunit"
            "SELECT (SELECT sum(file_size) FROM chunk)::float / nullif((SELECT sum(nar_size) FROM nar), 0)"
          )
          {
            type = "timeseries";
            title = "Paths pushed per day";
            datasource = ds;
            gridPos = {
              x = 0;
              y = 4;
              w = 12;
              h = 8;
            };
            targets = [
              (query "time_series" ''
                SELECT date_trunc('day', created_at) AS time, count(*) AS pushed
                FROM object WHERE $__timeFilter(created_at) GROUP BY 1 ORDER BY 1
              '')
            ];
            fieldConfig.defaults.custom.drawStyle = "bars";
          }
          {
            type = "timeseries";
            title = "Free disk (${config.networking.hostName})";
            datasource = {
              type = "prometheus";
              uid = "victoriametrics";
            };
            gridPos = {
              x = 12;
              y = 4;
              w = 12;
              h = 8;
            };
            targets = [
              {
                refId = "A";
                expr = ''node_filesystem_avail_bytes{instance="${config.networking.hostName}",mountpoint="/"}'';
                legendFormat = "free";
              }
            ];
            fieldConfig.defaults.unit = "bytes";
          }
          (table 0 "Largest paths" ''
            SELECT ${shortPath} AS path, n.nar_size AS size, o.created_at AS pushed
            FROM object o JOIN nar n ON n.id = o.nar_id ORDER BY n.nar_size DESC LIMIT 25
          '')
          (table 12 "Latest pushes" ''
            SELECT o.created_at AS pushed, ${shortPath} AS path, n.nar_size AS size
            FROM object o JOIN nar n ON n.id = o.nar_id ORDER BY o.created_at DESC LIMIT 25
          '')
        ];
      }
    );

  hasAttic = config.polaris.services.attic.enable;

  grafana-postgresql-datasource = pkgs.grafanaPlugins.grafanaPlugin {
    pname = "grafana-postgresql-datasource";
    version = "13.0.7";
    packages.linux-amd64 = {
      url = "https://grafana.com/api/plugins/grafana-postgresql-datasource/versions/13.0.7/download?os=linux&arch=amd64";
      hash = "sha256-vHIvwZQHM5CsX7+KSyRwlj6m+0mwrFyeRfpgNnnNEbg=";
    };
  };

  dashboards = pkgs.linkFarm "grafana-dashboards" (
    lib.optionalAttrs hasAttic { "Services/attic.json" = atticDashboard; }
    // {
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
      "Services/caddy.json" = fetchDashboard {
        id = 24146;
        rev = 1;
        hash = "sha256-vw/O3bNKQ0tJwhsZKYvkMU6jeqkG+sfCtA7YT0vp3YY=";
        replace = [
          [
            "\${DS_PROMETHEUS}"
            "victoriametrics"
          ]
        ];
      };
      "Services/postgres.json" = fetchDashboard {
        id = 24919;
        rev = 1;
        hash = "sha256-BHr2pJL7rZ4RCITh6pJOdwRenvIJNKJb5JGJjm6N5PU=";
        replace = [
          [
            "\${DS_VICTORIAMETRICS}"
            "victoriametrics"
          ]
        ];
      };
      "Services/unbound.json" = fetchDashboard {
        id = 21006;
        rev = 4;
        hash = "sha256-Z+y+8MCIpjgPW12Q2jcbNhaL/WA00SL2uPT/7KKsOVw=";
      };
      "Services/ntfy.json" = fetchDashboard {
        url = "https://raw.githubusercontent.com/binwiederhier/ntfy/v2.32.0/examples/grafana-dashboard/ntfy-grafana.json";
        hash = "sha256-hSOr3TsDYsYLG13zvfzsXwDWk3b4f5ZoRPwg+B1vnqg=";
        replace = [
          [
            "\${DS_PROMETHEUS}"
            "victoriametrics"
          ]
        ];
      };
      "Services/garage.json" = fetchDashboard {
        url = "https://git.deuxfleurs.fr/Deuxfleurs/garage/raw/tag/v2.4.1/script/telemetry/grafana-garage-dashboard-prometheus.json";
        hash = "sha256-VUAheA6DTB8TWUhYOwH/O03XqmD7WAhEx5kF4R/Recs=";
        replace = [
          [
            "\${DS_DS_PROMETHEUS}"
            "victoriametrics"
          ]
        ];
      };
      "Services/gatus.json" = fetchDashboard {
        url = "https://raw.githubusercontent.com/TwiN/gatus/v5.36.0/.examples/docker-compose-grafana-prometheus/grafana/provisioning/dashboards/gatus.json";
        hash = "sha256-qXo73c9rR30nxjnnkh3e7gd3GKkMi0kaVxJFBHCDq1o=";
        replace = [
          [
            ''"value": "cedv077q7bbwgd"''
            ''"value": "victoriametrics"''
          ]
        ];
      };
      "Services/forgejo.json" = fetchDashboard {
        # gitea dashboard; forgejo exports the same gitea_* metrics
        id = 13192;
        rev = 1;
        hash = "sha256-IAaI/HvMxcWE3PGQFK8avNjgj88DgcDvkWRcDAWSejM=";
        replace = [
          [
            "\${DS_PROMETHEUS}"
            "VictoriaMetrics"
          ]
          [
            ''job=\"gitea\"''
            ''job=\"forgejo\"''
          ]
        ];
      };
    }
  );

  # polaris.services.monitoring.exports of every host, grouped by job
  targets = lib.groupBy (t: t.job) (
    lib.concatLists (
      lib.mapAttrsToList (
        host: node:
        lib.mapAttrsToList (
          job: e: e // { inherit host job; }
        ) node.config.polaris.services.monitoring.exports
      ) inputs.self.nixosConfigurations
    )
  );
  tokenJobs = lib.filterAttrs (_: ts: (lib.head ts).bearerTokenSecret != null) targets;
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
        scrape_configs =
          lib.mapAttrsToList (
            job: ts:
            {
              job_name = job;
              metrics_path = (lib.head ts).path;
              static_configs = map (t: {
                targets = [ "${hosts.${t.host}.internal.fqdn}:${toString t.port}" ];
                labels.instance = t.host;
              }) ts;
            }
            // lib.optionalAttrs (tokenJobs ? ${job}) {
              bearer_token_file = "/run/credentials/victoriametrics.service/${job}";
            }
          ) targets
          ++ [
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

    systemd.services.victoriametrics.serviceConfig.LoadCredential = lib.mapAttrsToList (
      job: ts: "${job}:${config.security.nix-secrets.secrets.${(lib.head ts).bearerTokenSecret}.path}"
    ) tokenJobs;

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
      declarativePlugins =
        with pkgs.grafanaPlugins;
        [
          prometheus
          victoriametrics-logs-datasource
          grafana-metricsdrilldown-app
        ]
        ++ lib.optional hasAttic grafana-postgresql-datasource;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = cfg.port;
          inherit (cfg) domain;
          root_url = "https://${cfg.domain}/";
          enable_gzip = true;
        };
        log.level = "warn";
        database = {
          type = "postgres";
          host = "/run/postgresql";
          name = "grafana";
          user = "grafana";
        };
        security = {
          secret_key = "$__file{${config.security.nix-secrets.secrets."grafana/secret_key".path}}";
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
          client_secret = "$__file{${config.security.nix-secrets.secrets."grafana/clientSecret".path}}";
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
        ]
        ++ lib.optional hasAttic {
          name = "Attic";
          uid = "attic";
          type = "grafana-postgresql-datasource";
          # peer auth over the socket, as the grafana role
          url = "/run/postgresql";
          user = "grafana";
          jsonData = {
            database = "atticd";
            sslmode = "disable";
          };
        };
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

    polaris.backup2.postgresql.databases = [
      "grafana"
    ];

    # after atticd-provision, which runs attic's migrations
    systemd.services.grafana-attic-grants = lib.mkIf hasAttic {
      description = "Read-only access to atticd for grafana";
      requires = [ "atticd-provision.service" ];
      after = [ "atticd-provision.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
      };
      script = "${config.services.postgresql.package}/bin/psql -d atticd -v ON_ERROR_STOP=1 -f ${atticGrantsSql}";
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
        reverse_proxy 127.0.0.1:${toString cfg.port}
      '';
      "http://${cfg.intraDomain}" = {
        listenAddresses = config.polaris.services.caddy.internalListenAddresses;
        extraConfig = ''
          redir https://${cfg.domain}{uri} temporary
        '';
      };
    };

    security.nix-secrets.secrets =
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
      }
      // lib.mapAttrs' (_: ts: lib.nameValuePair (lib.head ts).bearerTokenSecret { }) tokenJobs;
  };
}
