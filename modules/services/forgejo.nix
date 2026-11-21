{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.forgejo;
  idp = libx.idp {
    domain = config.polaris.services.kanidm.domain;
    inherit (cfg) client_id;
  };
  catppuccin-gitea = pkgs.fetchzip {
    url = "https://github.com/griffi-gh/catppuccin-gitea/releases/download/v1.0.1/catppuccin-gitea.tar.gz";
    hash = "sha256-fpQM3ghvMOuzP6B9p0b0ogjkk6/KZVOc/5e65JJVSso=";
    stripRoot = false;
  };
in
{
  options.polaris.services.forgejo = {
    enable = lib.mkEnableOption "forgejo";
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "forgejo.polaris";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "git.lunya.cc";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "forgejo";
    };
    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 16130;
    };
  };

  config = lib.mkIf cfg.enable {
    polaris.services.oauth2_proxy.enable = true;

    polaris.backup2 = {
      paths = [ config.services.forgejo.stateDir ];
      # (skip forgejo's own dumps)
      exclude = [
        config.services.forgejo.dump.backupDir
        "${config.services.forgejo.stateDir}/log"
      ];
      postgresql.databases = [
        config.services.forgejo.database.name
      ];
    };

    services.forgejo = {
      enable = true;
      package = pkgs.forgejo;
      lfs.enable = true;
      dump = {
        enable = true;
        age = "7d";
      };
      database = {
        type = "postgres";
        createDatabase = true;
      };
      useWizard = false;
      secrets = {
        security.SECRET_KEY = lib.mkForce config.security.nix-secrets.secrets."forgejo/secret_key".path;
        security.INTERNAL_TOKEN = lib.mkForce config.security.nix-secrets.secrets."forgejo/internal_token".path;
        oauth2.JWT_SECRET = lib.mkForce config.security.nix-secrets.secrets."forgejo/jwt_secret".path;
        server.LFS_JWT_SECRET = lib.mkForce config.security.nix-secrets.secrets."forgejo/lfs_jwt_secret".path;
      };
      settings = {
        server = {
          ROOT_URL = "https://${cfg.domain}/";
          DOMAIN = cfg.domain;
          PROTOCOL = "http+unix";
          DISABLE_SSH = true; # SSH_PORT = 2222; TODO
          OFFLINE_MODE = false;
          ENABLE_GZIP = true;
          STATIC_CACHE_TIME = "8760h"; # asset urls are versioned (default 6h)
          LANDING_PAGE = "explore";
        };
        security = {
          INSTALL_LOCK = true;
          PASSWORD_HASH_ALGO = "argon2";
          CSRF_COOKIE_HTTP_ONLY = true;
          DISABLE_QUERY_AUTH_TOKEN = true;
        };
        service = {
          DISABLE_REGISTRATION = false;
          SHOW_REGISTRATION_BUTTON = false;
          ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          ENABLE_INTERNAL_SIGNIN = false;
          ENABLE_BASIC_AUTHENTICATION = false;
          USERNAME_COOLDOWN_PERIOD = 365; # days
          DEFAULT_KEEP_EMAIL_PRIVATE = true;
        };
        # NOTE: only register runners scoped to an org/user/repo
        actions.ENABLED = true;
        packages.ENABLED = true;
        # users without a quota group (= external signups) use this budget
        quota.ENABLED = true;
        "quota.default".TOTAL = "1G";
        migrations.ALLOW_LOCALNETWORKS = false;
        webhook.ALLOWED_HOST_LIST = "external";
        moderation.ENABLED = true;
        session = {
          DOMAIN = cfg.domain;
          COOKIE_SECURE = true;
        };
        openid = {
          ENABLE_OPENID_SIGNIN = false;
          ENABLE_OPENID_SIGNUP = false;
          WHITELISTED_URIS = config.polaris.services.kanidm.domain;
        };
        oauth2_client = {
          OPENID_CONNECT_SCOPES = "profile email groups";
          ENABLE_AUTO_REGISTRATION = true;
          ACCOUNT_LINKING = "login";
          USERNAME = "nickname"; # preferred_username?
          UPDATE_AVATAR = true;
        };
        picture = {
          DISABLE_GRAVATAR = false;
          GRAVATAR_SOURCE = "gravatar";
          ENABLE_FEDERATED_AVATAR = true;
        };
        metrics.ENABLED = true;
        repository = {
          DEFAULT_BRANCH = "master"; # sorry im too used to this one :p
        };
        indexer = {
          REPO_INDEXER_ENABLED = true;
          REPO_INDEXER_FUZZY_ENABLED = true;
        };
        ui = {
          DEFAULT_THEME = "catppuccin-pink-auto";
          THEMES = lib.concatStringsSep "," [
            "forgejo-auto"
            "forgejo-light"
            "forgejo-dark"

            "gitea-auto"
            "gitea-light"
            "gitea-dark"

            "forgejo-auto-deuteranopia-protanopia"
            "forgejo-light-deuteranopia-protanopia"
            "forgejo-dark-deuteranopia-protanopia"

            "forgejo-auto-tritanopia"
            "forgejo-light-tritanopia"
            "forgejo-dark-tritanopia"

            "catppuccin-rosewater-auto"
            "catppuccin-flamingo-auto"
            "catppuccin-pink-auto"
            "catppuccin-mauve-auto"
            "catppuccin-red-auto"
            "catppuccin-maroon-auto"
            "catppuccin-peach-auto"
            "catppuccin-yellow-auto"
            "catppuccin-green-auto"
            "catppuccin-teal-auto"
            "catppuccin-sky-auto"
            "catppuccin-sapphire-auto"
            "catppuccin-blue-auto"
            "catppuccin-lavender-auto"

            "catppuccin-latte-rosewater"
            "catppuccin-latte-flamingo"
            "catppuccin-latte-pink"
            "catppuccin-latte-mauve"
            "catppuccin-latte-red"
            "catppuccin-latte-maroon"
            "catppuccin-latte-peach"
            "catppuccin-latte-yellow"
            "catppuccin-latte-green"
            "catppuccin-latte-teal"
            "catppuccin-latte-sky"
            "catppuccin-latte-sapphire"
            "catppuccin-latte-blue"
            "catppuccin-latte-lavender"
            "catppuccin-frappe-rosewater"
            "catppuccin-frappe-flamingo"
            "catppuccin-frappe-pink"
            "catppuccin-frappe-mauve"
            "catppuccin-frappe-red"
            "catppuccin-frappe-maroon"
            "catppuccin-frappe-peach"
            "catppuccin-frappe-yellow"
            "catppuccin-frappe-green"
            "catppuccin-frappe-teal"
            "catppuccin-frappe-sky"
            "catppuccin-frappe-sapphire"
            "catppuccin-frappe-blue"
            "catppuccin-frappe-lavender"
            "catppuccin-macchiato-rosewater"
            "catppuccin-macchiato-flamingo"
            "catppuccin-macchiato-pink"
            "catppuccin-macchiato-mauve"
            "catppuccin-macchiato-red"
            "catppuccin-macchiato-maroon"
            "catppuccin-macchiato-peach"
            "catppuccin-macchiato-yellow"
            "catppuccin-macchiato-green"
            "catppuccin-macchiato-teal"
            "catppuccin-macchiato-sky"
            "catppuccin-macchiato-sapphire"
            "catppuccin-macchiato-blue"
            "catppuccin-macchiato-lavender"
            "catppuccin-mocha-rosewater"
            "catppuccin-mocha-flamingo"
            "catppuccin-mocha-pink"
            "catppuccin-mocha-mauve"
            "catppuccin-mocha-red"
            "catppuccin-mocha-maroon"
            "catppuccin-mocha-peach"
            "catppuccin-mocha-yellow"
            "catppuccin-mocha-green"
            "catppuccin-mocha-teal"
            "catppuccin-mocha-sky"
            "catppuccin-mocha-sapphire"
            "catppuccin-mocha-blue"
            "catppuccin-mocha-lavender"
          ];
        };

        # TODO:
        # federation = {
        #   ENABLED = true;
        # };
        # TODO:
        # redis as cache/session provider
        # TODO:
        # ENABLE_CAPTCHA = true;
        # CAPTCHA_TYPE = "mcaptcha";
        # REQUIRE_CAPTCHA_FOR_LOGIN = true;
        # REQUIRE_EXTERNAL_REGISTRATION_CAPTCHA = true;
      };
    };

    # provision oauth providers
    systemd.services.forgejo.postStart =
      let
        exe = lib.getExe config.services.forgejo.package;
        providers = [
          {
            args = {
              provider = "openidConnect";
              name = "kanidm_internal";
              key = cfg.client_id;
              auto-discover-url = idp.oidc_discovery;
              scopes = "profile email groups";
              allow-username-change = true;
              group-claim-name = "groups";
              admin-group = "forgejo.admin@sso.girl.pp.ua";
              # internal users -> unlimited quota group (outsiders stay on [quota.default])
              quota-group-claim-name = "forgejo_quota";
              quota-group-map = builtins.toJSON { internal = [ "internal" ]; };
              quota-group-map-removal = true;
            };
            secretFile = config.security.nix-secrets.secrets."forgejo/clientSecret".path;
          }
          {
            args = {
              provider = "github";
              name = "github";
              scopes = "read:user user:email";
            };
            keyFile = config.security.nix-secrets.secrets."forgejo/github/clientId".path;
            secretFile = config.security.nix-secrets.secrets."forgejo/github/clientSecret".path;
          }
          {
            args = {
              provider = "gitea";
              name = "codeberg";
              use-custom-urls = "true";
              custom-auth-url = "https://codeberg.org/login/oauth/authorize";
              custom-token-url = "https://codeberg.org/login/oauth/access_token";
              custom-profile-url = "https://codeberg.org/login/oauth/userinfo";
              icon-url = "https://codeberg.org/assets/img/favicon.svg";
            };
            keyFile = config.security.nix-secrets.secrets."forgejo/codeberg/clientId".path;
            secretFile = config.security.nix-secrets.secrets."forgejo/codeberg/clientSecret".path;
          }
          {
            args = {
              provider = "gitlab";
              name = "gitlab";
              scopes = "read_user";
            };
            keyFile = config.security.nix-secrets.secrets."forgejo/gitlab/clientId".path;
            secretFile = config.security.nix-secrets.secrets."forgejo/gitlab/clientSecret".path;
          }
        ];
        customConf = "--work-path ${config.services.forgejo.stateDir} --config ${config.services.forgejo.customDir}/conf/app.ini";
        provision =
          p:
          let
            inherit (p.args) name;
            args =
              lib.cli.toCommandLineShellGNU { } p.args
              + lib.optionalString (p ? keyFile) " --key \"$(< ${p.keyFile})\""
              + " --secret \"$(< ${p.secretFile})\"";
          in
          ''
            provider_id=$(${exe} admin auth list ${customConf} 2>/dev/null | grep -w '${name}' | cut -f1)
            if [[ -z "$provider_id" ]]; then
              echo "adding ${name}"
              ${exe} admin auth add-oauth ${customConf} ${args}
            else
              echo "updating ${name}"
              ${exe} admin auth update-oauth ${customConf} --id "$provider_id" ${args}
            fi
          '';
      in
      lib.concatMapStrings provision providers;

    # sso doesn't resolve, keep retrying
    systemd.services.forgejo.startLimitIntervalSec = 0;
    systemd.services.forgejo.serviceConfig.RestartSec = "5s";

    # anyone with a github/codeberg/gitlab account can sign up, and forgejo's webhook/migration
    # "external host" checks treat tailscale's cgnat range as public, so keep forgejo itself
    # off the tailnet and private networks (it only talks over unix sockets locally)
    systemd.services.forgejo.serviceConfig.IPAddressDeny = [
      "100.64.0.0/10"
      "fd7a:115c:a1e0::/48"
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "169.254.0.0/16"
      "fc00::/7"
      "fe80::/10"
    ];

    # quota groups can only be managed through the api, so this uses a temp local admin account
    systemd.services.forgejo-quota-groups =
      let
        fj = config.services.forgejo;
        bot = "quota-provisioner";
      in
      {
        description = "Provision forgejo quota groups";
        after = [ "forgejo.service" ];
        requires = [ "forgejo.service" ];
        wantedBy = [ "forgejo.service" ];
        path = [
          pkgs.curl
          pkgs.jq
        ];
        serviceConfig = {
          Type = "oneshot";
          User = fj.user;
          Group = fj.group;
          # (forgejo may not be listening yet right after it starts)
          Restart = "on-failure";
          RestartSec = "10s";
        };
        script = ''
          set -euo pipefail

          fj() { ${lib.getExe fj.package} --work-path ${fj.stateDir} --config ${fj.customDir}/conf/app.ini "$@"; }
          tokenFile=${fj.stateDir}/${bot}.token
          if [[ ! -s $tokenFile ]]; then
            if ! fj admin user list --admin | grep -qw ${bot}; then
              fj admin user create --admin --username ${bot} --email ${bot}@localhost \
                --random-password --must-change-password=false >/dev/null
            fi
            (umask 077; fj admin user generate-access-token --username ${bot} \
              --token-name "provisioning-$(date +%s)" --scopes write:admin --raw > "$tokenFile.tmp")
            mv "$tokenFile.tmp" "$tokenFile"
          fi
          curl_api() {
            curl -sS --unix-socket ${fj.settings.server.HTTP_ADDR} \
              -H "Authorization: token $(<"$tokenFile")" -H 'Content-Type: application/json' "$@"
          }
          api() { curl_api -o /dev/null -w '%{http_code}' "$@"; }
          api_base=http://localhost/api/v1
          base=$api_base/admin/quota/groups

          code=$(api "$base/internal")
          if [[ $code == 404 ]]; then
            code=$(api -X POST "$base" -d '{"name":"internal","rules":[{"name":"internal-unlimited","limit":-1,"subjects":["size:all"]}]}')
            [[ $code == 2* ]] || { echo "creating quota group 'internal' failed: HTTP $code" >&2; exit 1; }
          elif [[ $code != 2* ]]; then
            echo "checking quota group 'internal' failed: HTTP $code" >&2; exit 1
          fi

          # existing users of the kanidm source
          source_id=$(fj admin auth list | grep -w kanidm_internal | cut -f1)
          [[ -n $source_id ]] || { echo "auth source kanidm_internal not found" >&2; exit 1; }
          page=1
          while :; do
            users=$(curl_api -f "$api_base/admin/users?source_id=$source_id&limit=50&page=$page" | jq -r '.[].login')
            [[ -n $users ]] || break
            for user in $users; do
              code=$(api -X PUT "$base/internal/users/$user")
              # (409 = already a member)
              [[ $code == 2* || $code == 409 ]] || echo "adding $user to quota group 'internal' failed: HTTP $code" >&2
            done
            page=$((page + 1))
          done
        '';
      };

    # specify secrets explicitly
    systemd.services.forgejo-secrets.script = lib.mkForce "${pkgs.coreutils}/bin/true";

    # custom stuff
    systemd.tmpfiles.rules = [
      "d '${config.services.forgejo.customDir}/public' 0750 ${config.services.forgejo.user} ${config.services.forgejo.group} - -"
      "d '${config.services.forgejo.customDir}/public/assets' 0750 ${config.services.forgejo.user} ${config.services.forgejo.group} - -"
      "r '${config.services.forgejo.customDir}/public/assets/css'"
      "L '${config.services.forgejo.customDir}/public/assets/css' - - - - ${catppuccin-gitea}"
    ];

    # confgure caddy
    services.caddy.virtualHosts."http://${cfg.intraDomain}" = {
      listenAddresses = config.polaris.services.caddy.internalListenAddresses;
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode
        respond /metrics 404

        import oauth2_proxy_handle

        # force interactive login on session expiry
        @kanidm_silent {
          path /user/oauth2/kanidm_internal
          query prompt=none
        }
        redir @kanidm_silent /user/oauth2/kanidm_internal

        @admin path /admin /admin/* /api/v1/admin/*
        handle @admin {
          import oauth2_proxy_secure_external "forgejo_admin"
          reverse_proxy unix/${config.services.forgejo.settings.server.HTTP_ADDR}
        }

        reverse_proxy unix/${config.services.forgejo.settings.server.HTTP_ADDR}
      '';
    };
    # forgejo only listens on a unix socket, so give the collector its own port
    services.caddy.virtualHosts."http://:${toString cfg.metricsPort}".extraConfig = ''
      handle /metrics {
        reverse_proxy unix/${config.services.forgejo.settings.server.HTTP_ADDR}
      }
      respond 403
    '';
    polaris.services.monitoring.exports.forgejo.port = cfg.metricsPort;

    security.nix-secrets.secrets = {
      "forgejo/secret_key" = { };
      "forgejo/internal_token" = { };
      "forgejo/jwt_secret" = { };
      "forgejo/lfs_jwt_secret" = { };
    }
    //
      lib.genAttrs
        [
          "forgejo/clientSecret"
          "forgejo/github/clientId"
          "forgejo/github/clientSecret"
          "forgejo/codeberg/clientId"
          "forgejo/codeberg/clientSecret"
          "forgejo/gitlab/clientId"
          "forgejo/gitlab/clientSecret"
        ]
        (_: {
          owner = config.services.forgejo.user;
          group = config.services.forgejo.group;
          mode = "0400";
        });
  };
}
