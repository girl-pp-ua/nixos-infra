{ config, pkgs, lib, inputs, ... }:
let cfg = config.cfg; in {
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
        ];
      };
    };
  };
  config = lib.mkIf cfg.services.uptime-kuma.enable {

    services.uptime-kuma = {
      enable = true;
      package = pkgs.uptime-kuma.overrideAttrs (prev: rec {
        version = "2.0.0-beta";
        src = "${inputs.uptime-kuma}";
        npmDeps = pkgs.fetchNpmDeps {
          inherit src;
          name = "${prev.pname}-${version}-npm-deps";
          hash = "sha256-DuXBu536Ro6NA3pPnP1mL+hBdgKCSudV0rxD2vZwX3o=";
        };
        patches = []; # (patch does not apply to 2.0.0-beta, see workaround below)
      });
      settings = {
        UPTIME_KUMA_HOST = "127.0.0.1";
        UPTIME_KUMA_PORT = builtins.toString cfg.services.uptime-kuma.port;
        UPTIME_KUMA_DB_TYPE = "sqlite";
        NODE_EXTRA_CA_CERTS = "${cfg.secrets.selfSignedCert.tls_chain}";
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

    services.caddy.virtualHosts = {
      ${cfg.services.uptime-kuma.domain} = {
        extraConfig = ''
          import oauth2_proxy
          import encode
          reverse_proxy http://127.0.0.1:${toString cfg.services.uptime-kuma.port}
        '';
      };
    } // (lib.optionalAttrs (builtins.length cfg.services.uptime-kuma.statusPages != 0) {
      ${builtins.head cfg.services.uptime-kuma.statusPages} = {
        serverAliases = builtins.tail cfg.services.uptime-kuma.statusPages;
        extraConfig = ''
          import encode
          @allow {
            path /
            path /icon.svg
            path /assets/*
            path /api/entry-page
            path /api/status-page/heartbeat/*
          }
          handle @allow {
            reverse_proxy http://127.0.0.1:${toString cfg.services.uptime-kuma.port}
          }
          handle {
            redir https://uptime.girl.pp.ua{uri}
          }
        '';
      };
    });
  };
}