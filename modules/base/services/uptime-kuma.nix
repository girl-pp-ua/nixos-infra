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
  options = {
    cfg.services.uptime-kuma = {
      enable = lib.mkEnableOption "uptime-kuma";
      port = lib.mkOption {
        type = lib.types.int;
        default = 16003;
      };
      domain = lib.mkOption {
        type = lib.types.str;
        default = "uptime.girl.pp.ua";
      };
      statusPages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "status.nyanbinary.rs"
          "status.girl.pp.ua"
        ];
      };
    };
  };
  config = lib.mkIf cfg.services.uptime-kuma.enable {
    services.uptime-kuma = {
      enable = true;
      package = pkgs.uptime-kuma.overrideAttrs (prev: rec {
        version = "2.0.0";
        src = "${inputs.uptime-kuma}";
        npmDeps = pkgs.fetchNpmDeps {
          inherit src;
          name = "${prev.pname}-${version}-npm-deps";
          hash = "sha256-YZS6rUE7qi11gFqiZ7AU4u2JKmTLeqiQ0wVPbOA8KBg=";
        };
        patches = [ ]; # (patch does not apply to 2.0.0-beta, see workaround below)
      });
      settings = {
        UPTIME_KUMA_HOST = "127.0.0.1";
        UPTIME_KUMA_PORT = builtins.toString cfg.services.uptime-kuma.port;
        UPTIME_KUMA_DB_TYPE = "sqlite";
        NODE_EXTRA_CA_CERTS = "/run/credentials/uptime-kuma.service/uptime_kuma_tls_chain.pem";
      };
      # // (
      #   lib.optionalAttrs
      #   (builtins.hasAttr "/data" config.fileSystems)
      #   {
      #     DATA_DIR = lib.mkForce "/data/uptime-kuma";
      #   }
      # );
    };

    # workaround
    systemd.tmpfiles.rules = [
      "f /var/lib/uptime-kuma/kuma.db 0644 - - -"
    ];

    services.caddy.virtualHosts =
      {
        ${cfg.services.uptime-kuma.domain} = {
          extraConfig = ''
            import oauth2_proxy
            import encode
            reverse_proxy http://127.0.0.1:${toString cfg.services.uptime-kuma.port}
          '';
        };
      }
      // (lib.optionalAttrs (builtins.length cfg.services.uptime-kuma.statusPages != 0) {
        ${builtins.head cfg.services.uptime-kuma.statusPages} = {
          serverAliases = builtins.tail cfg.services.uptime-kuma.statusPages;
          extraConfig = ''
            import encode

            redir /status /
            redir /status/* /

            @allow {
              path /
              path /manifest.json
              path /favicon.ico
              path /apple-touch-icon.png
              path /icon-192x192.png
              path /icon-512x512.png
              path /icon.svg
              path /assets/index-*.js
              path /assets/index-*.css
              path /upload/logo*.png
              path /api/entry-page
              path /api/status-page/heartbeat/*
              path /api/status-page/*/manifest.json
            }
            handle @allow {
              reverse_proxy http://127.0.0.1:${toString cfg.services.uptime-kuma.port}
            }

            @deny {
              path /socket.io
              path /socket.io/*
            }
            handle @deny {
              respond 403
            }

            handle {
              redir https://uptime.girl.pp.ua{uri}
            }
          '';
        };
      });

    systemd.services.uptime-kuma.serviceConfig = {
      LoadCredential = "uptime_kuma_tls_chain.pem:${config.sops.secrets."uptime_kuma_tls_chain".path}";
    };
    sops.secrets."uptime_kuma_tls_chain" = {
      sopsFile = "${inputs.secrets}/certs/tls_chain.sops.pem";
      format = "binary";
    };
  };
}
