{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.bookorbit;
  idp = libx.idp {
    domain = config.polaris.services.kanidm.domain;
    inherit (cfg) client_id;
  };

  provisionSql = pkgs.writeText "bookorbit-provision.sql" ''
    \getenv client_secret BOOKORBIT_CLIENT_SECRET

    INSERT INTO oidc_providers
      (slug, display_name, enabled, issuer_uri, client_id, client_secret, scopes, claim_mapping, auto_provision, display_order)
    VALUES
      (:'slug', :'display_name', true, :'issuer_uri', :'client_id', :'client_secret', :'scopes',
       :'claim_mapping'::jsonb, :'auto_provision'::jsonb, 0)
    ON CONFLICT (slug) DO UPDATE SET
      display_name = EXCLUDED.display_name,
      enabled = EXCLUDED.enabled,
      issuer_uri = EXCLUDED.issuer_uri,
      client_id = EXCLUDED.client_id,
      client_secret = EXCLUDED.client_secret,
      scopes = EXCLUDED.scopes,
      claim_mapping = EXCLUDED.claim_mapping,
      auto_provision = EXCLUDED.auto_provision,
      updated_at = now();

    WITH provider AS (
      SELECT id FROM oidc_providers WHERE slug = :'slug'
    ), dummy AS (
      INSERT INTO users (username, name, password_hash, is_superuser, active, provisioning_method)
      VALUES (:'dummy_username', :'dummy_name', :'password_hash', true, true, 'oidc')
      ON CONFLICT (username) DO UPDATE SET
        is_superuser = true,
        active = true
      RETURNING id
    )
    INSERT INTO oidc_identities (user_id, provider_id, oidc_subject, oidc_issuer)
    SELECT dummy.id, provider.id, :'subject', :'issuer_uri' FROM dummy, provider
    ON CONFLICT (user_id, provider_id) DO NOTHING;

    WITH provider AS (
      SELECT id FROM oidc_providers WHERE slug = :'slug'
    ), wanted AS (
      SELECT jsonb_array_elements_text(:'permissions'::jsonb) AS permission
    ), inserted AS (
      INSERT INTO oidc_group_mappings (provider_id, oidc_group_claim, permission_name)
      SELECT provider.id, wanted.permission, wanted.permission FROM provider, wanted
      ON CONFLICT (provider_id, oidc_group_claim) DO UPDATE SET
        permission_name = EXCLUDED.permission_name
      RETURNING 1
    )
    DELETE FROM oidc_group_mappings
    WHERE provider_id = (SELECT id FROM provider)
      AND oidc_group_claim NOT IN (SELECT permission FROM wanted);

    CREATE OR REPLACE FUNCTION bookorbit_sync_superuser() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      UPDATE users u SET is_superuser = EXISTS (
        SELECT 1 FROM user_permissions p
        WHERE p.user_id = u.id AND p.permission_name = 'superuser'
      )
      WHERE u.id = coalesce(NEW.user_id, OLD.user_id);
      RETURN NULL;
    END;
    $$;

    DROP TRIGGER IF EXISTS bookorbit_sync_superuser ON user_permissions;
    CREATE TRIGGER bookorbit_sync_superuser
      AFTER INSERT OR DELETE ON user_permissions
      FOR EACH ROW EXECUTE FUNCTION bookorbit_sync_superuser();

    UPDATE users u SET is_superuser = EXISTS (
      SELECT 1 FROM user_permissions p
      WHERE p.user_id = u.id AND p.permission_name = 'superuser'
    )
    WHERE u.username <> :'dummy_username'
      AND u.is_superuser <> EXISTS (
        SELECT 1 FROM user_permissions p
        WHERE p.user_id = u.id AND p.permission_name = 'superuser'
      );

    INSERT INTO user_library_access (user_id, library_id, access_level)
    SELECT u.id, l.id, 'viewer' FROM users u, libraries l
    WHERE u.active AND u.username <> :'dummy_username'
    ON CONFLICT (user_id, library_id) DO NOTHING;

    INSERT INTO app_settings (key, value)
    SELECT 'default_library_access',
           jsonb_build_object('libraryIds', coalesce(jsonb_agg(l.id), '[]'::jsonb))::text
    FROM libraries l
    ON CONFLICT (key) DO UPDATE SET
      value = EXCLUDED.value,
      updated_at = now();
  '';
in
{
  options.polaris.services.bookorbit = {
    enable = lib.mkEnableOption "bookorbit";
    port = lib.mkOption {
      type = lib.types.port;
      default = 16110;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "books.lunya.cc";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "bookorbit.polaris";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "bookorbit";
    };
    booksDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/bookorbit/books";
    };
    sso = {
      slug = lib.mkOption {
        type = lib.types.str;
        default = "kanidm";
      };
      displayName = lib.mkOption {
        type = lib.types.str;
        default = "Girlcock";
      };
      permissionsClaim = lib.mkOption {
        type = lib.types.str;
        default = "bookorbit_permissions";
      };
      permissions = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {
          "bookorbit.access" = [
            "library_download"
            "opds_access"
            "kobo_sync"
            "koreader_sync"
            "hardcover_sync"
            "readwise_sync"
            "storygraph_sync"
            "book_request_access"
            "email_send"
            "notification_access"
          ];
          "bookorbit.admin" = [
            "library_upload"
            "library_edit_metadata"
            "library_delete_books"
            "book_dock_access"
            "manage_email"
            "manage_libraries"
            "manage_metadata_config"
            "manage_icons"
            "manage_app_settings"
            "manage_book_dock"
            "manage_book_requests"
            "book_request_auto_approve"
            "book_request_self_fulfill"
            "manage_users"
            "view_user_activity"
            "view_audit_log"
            "superuser"
          ];
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.bookorbit = {
      enable = true;
      createDatabaseLocally = true;
      environment = {
        HOST = "127.0.0.1";
        PORT = cfg.port;
        APP_URL = "https://${cfg.domain}";
        TRUST_PROXY = lib.concatStringsSep "," config.polaris.trustedNetworks;
        LIBRARY_BROWSE_ROOT = cfg.booksDir;
        DISABLE_LOCAL_AUTH = "true";
      };
      environmentFile = config.sops.templates."bookorbit.env".path;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.booksDir} 0750 ${config.services.bookorbit.user} ${config.services.bookorbit.group} -"
    ];

    systemd.services.bookorbit-sso-provision = {
      description = "BookOrbit SSO provisioning";
      after = [ "bookorbit-migrate.service" ];
      requires = [ "bookorbit-migrate.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.services.postgresql.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.services.bookorbit.user;
        Group = config.services.bookorbit.group;
        LoadCredential = [
          "clientSecret:${config.sops.secrets."bookorbit/clientSecret".path}"
        ];
      };
      script = ''
        BOOKORBIT_CLIENT_SECRET="$(cat "$CREDENTIALS_DIRECTORY/clientSecret")"
        export BOOKORBIT_CLIENT_SECRET
        psql "${config.services.bookorbit.environment.DATABASE_URL}" -v ON_ERROR_STOP=1 --single-transaction \
          --set=slug=${lib.escapeShellArg cfg.sso.slug} \
          --set=display_name=${lib.escapeShellArg cfg.sso.displayName} \
          --set=issuer_uri=${lib.escapeShellArg idp.oidc_issuer_uri} \
          --set=client_id=${lib.escapeShellArg cfg.client_id} \
          --set=scopes=${lib.escapeShellArg "openid profile email groups"} \
          --set=claim_mapping=${
            lib.escapeShellArg (
              builtins.toJSON {
                username = "preferred_username";
                name = "name";
                email = "email";
                groups = cfg.sso.permissionsClaim;
              }
            )
          } \
          --set=auto_provision=${
            lib.escapeShellArg (
              builtins.toJSON {
                enabled = true;
                allowLocalLinking = true;
                defaultPermissionNames = [ ];
              }
            )
          } \
          --set=permissions=${lib.escapeShellArg (builtins.toJSON (lib.unique (lib.concatLists (lib.attrValues cfg.sso.permissions))))} \
          --set=dummy_username=dummy-user \
          --set=dummy_name=${lib.escapeShellArg "dummy user, do not delete"} \
          --set=password_hash="\$2b\$12\$$(tr -dc 'A-Za-z0-9./' < /dev/urandom | head -c 53)" \
          --set=subject="dummy:$(tr -dc 'a-f0-9' < /dev/urandom | head -c 32)" \
          -f ${provisionSql}
      '';
    };

    systemd.services.bookorbit = {
      after = [ "bookorbit-sso-provision.service" ];
      wants = [ "bookorbit-sso-provision.service" ];
    };

    sops.secrets = {
      "bookorbit/clientSecret" = { };
      "bookorbit/jwt_secret" = { };
      "bookorbit/podcast_encryption_key" = { };
      "bookorbit/book_request_encryption_key" = { };
      "bookorbit/setup_bootstrap_token" = { };
    };
    sops.templates."bookorbit.env" = {
      mode = "0400";
      content = ''
        JWT_SECRET=${config.sops.placeholder."bookorbit/jwt_secret"}
        PODCAST_ENCRYPTION_KEY=${config.sops.placeholder."bookorbit/podcast_encryption_key"}
        BOOK_REQUEST_ENCRYPTION_KEY=${config.sops.placeholder."bookorbit/book_request_encryption_key"}
        SETUP_BOOTSTRAP_TOKEN=${config.sops.placeholder."bookorbit/setup_bootstrap_token"}
      '';
    };

    services.caddy.virtualHosts = {
      "${cfg.domain}" = {
        extraConfig = ''
          import encode
          import norobot
          reverse_proxy localhost:${toString cfg.port}
        '';
      };
      "http://${cfg.intraDomain}" = {
        extraConfig = ''
          import encode
          reverse_proxy localhost:${toString cfg.port}
        '';
      };
    };
  };
}
