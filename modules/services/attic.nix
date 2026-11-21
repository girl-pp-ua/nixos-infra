{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.polaris.services.attic;
  secretName = name: "attic/${name}_signing_key";

  provisionSql = pkgs.writeText "attic-provision.sql" ''
    \getenv keypair ATTIC_KEYPAIR

    INSERT INTO cache
      (name, keypair, is_public, store_dir, priority, upstream_cache_key_names, created_at)
    VALUES
      (:'name', :'keypair', :'is_public', '/nix/store', 41, '["cache.nixos.org-1"]', now())
    ON CONFLICT (name) DO UPDATE SET
      keypair = EXCLUDED.keypair,
      is_public = EXCLUDED.is_public,
      deleted_at = NULL;
  '';
in
{
  options.polaris.services.attic = {
    enable = lib.mkEnableOption "attic binary cache server";
    port = lib.mkOption {
      type = lib.types.port;
      default = 16111;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "cache.lunya.cc";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "cache.polaris";
    };
    caches = lib.mkOption {
      description = "Caches to create";
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.public = lib.mkEnableOption "unauthenticated pulls";
        }
      );
    };
  };

  config = lib.mkMerge [
    {
      # `nix-secrets -f .#<host> regenerate <secret>`
      security.nix-secrets.generators.attic-token =
        {
          sub,
          validity ? "10y",
          pull ? [ ],
          push ? [ ],
        }:
        let
          dummyConfig = (pkgs.formats.toml { }).generate "atticd-dummy.toml" {
            database.url = "sqlite::memory:";
            storage = {
              type = "local";
              path = "/nonexistent";
            };
            chunking = {
              nar-size-threshold = 65536;
              min-size = 16384;
              avg-size = 65536;
              max-size = 262144;
            };
          };
        in
        pkgs.writeShellScript "attic-token" ''
          set -euo pipefail
          ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="$(${lib.getExe pkgs.age} -d -i ~/.ssh/nixos_infra \
            "$NIX_SECRETS_STORAGE_PATH/attic/token_rs256_secret.enc")"
          export ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64
          token="$(${pkgs.attic-server}/bin/atticadm -f ${dummyConfig} make-token ${
            lib.cli.toCommandLineShellGNU { } {
              inherit
                sub
                validity
                pull
                push
                ;
            }
          })"
          printf 'machine ${cfg.domain}\npassword %s\n' "$token"
        '';
    }

    (lib.mkIf cfg.enable {
      services.atticd = {
        enable = true;
        environmentFile = config.security.nix-secrets.templates."atticd.env".path;
        settings = {
          listen = "127.0.0.1:${toString cfg.port}";

          substituter-endpoint = "https://${cfg.domain}/";
          allowed-hosts = [
            cfg.domain
            cfg.intraDomain
          ];

          # sqlx defaults to user "anonymous" without one
          database.url = "postgresql:///atticd?host=/run/postgresql&user=atticd";

          garbage-collection = {
            interval = "12 hours";
            default-retention-period = "3 months";
          };
        };
      };

      services.postgresql = {
        enable = true;
        ensureDatabases = [ "atticd" ];
        ensureUsers = [
          {
            name = "atticd";
            ensureDBOwnership = true;
          }
        ];
      };

      polaris.services.attic.caches.main = { };

      # local storage and db, nothing to reach besides caddy
      systemd.services.atticd.serviceConfig = {
        IPAddressDeny = "any";
        IPAddressAllow = "localhost";
      };

      systemd.services.atticd-provision = {
        description = "Provision attic caches";
        after = [ "postgresql.target" ];
        requires = [ "postgresql.target" ];
        before = [ "atticd.service" ];
        wantedBy = [ "atticd.service" ];
        path = [ config.services.postgresql.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          DynamicUser = true;
          User = config.services.atticd.user;
          Group = config.services.atticd.group;
          EnvironmentFile = config.services.atticd.environmentFile;
          PrivateNetwork = true;
          RestrictAddressFamilies = [ "AF_UNIX" ];
          inherit (config.systemd.services.atticd.serviceConfig)
            CapabilityBoundingSet
            DeviceAllow
            DevicePolicy
            LockPersonality
            MemoryDenyWriteExecute
            PrivateDevices
            PrivateUsers
            ProcSubset
            ProtectClock
            ProtectControlGroups
            ProtectHome
            ProtectHostname
            ProtectKernelLogs
            ProtectKernelModules
            ProtectKernelTunables
            ProtectProc
            RestrictNamespaces
            RestrictRealtime
            SystemCallArchitectures
            SystemCallFilter
            UMask
            ;
          LoadCredential = lib.mapAttrsToList (
            name: _: "${name}:${config.security.nix-secrets.secrets.${secretName name}.path}"
          ) cfg.caches;
        };
        # migrate here so the cache table exists before atticd
        script = ''
          ${lib.removeSuffix "--mode ${config.services.atticd.mode}" config.systemd.services.atticd.serviceConfig.ExecStart} --mode db-migrations
          db=${lib.escapeShellArg config.services.atticd.settings.database.url}
        ''
        + lib.concatStrings (
          lib.mapAttrsToList (name: c: ''
            ATTIC_KEYPAIR="$(cat "$CREDENTIALS_DIRECTORY/${name}")" \
            psql "$db" -v ON_ERROR_STOP=1 --single-transaction \
              --set=name=${lib.escapeShellArg name} \
              --set=is_public=${lib.boolToString c.public} \
              -f ${provisionSql}
          '') cfg.caches
        );
      };

      security.nix-secrets.secrets = {
        "attic/token_rs256_secret" = { };
      }
      // lib.mapAttrs' (name: _: lib.nameValuePair (secretName name) { }) cfg.caches;
      security.nix-secrets.templates."atticd.env".content = ''
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${
          config.security.nix-secrets.secrets."attic/token_rs256_secret".templateKey
        }
      '';

      services.caddy.virtualHosts = {
        "${cfg.domain}" = {
          extraConfig = ''
            import norobot
            reverse_proxy localhost:${toString cfg.port}
          '';
        };
        "http://${cfg.intraDomain}" = {
          listenAddresses = config.polaris.services.caddy.internalListenAddresses;
          extraConfig = ''
            reverse_proxy localhost:${toString cfg.port}
          '';
        };
      };
    })
  ];
}
