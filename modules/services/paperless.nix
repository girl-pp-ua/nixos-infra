{
  config,
  lib,
  libx,
  ...
}:
let
  cfg = config.cfg;
  idp = libx.idp {
    domain = cfg.services.kanidm.domain;
    client_id = cfg.services.paperless.clientId;
  };
in
{
  options.cfg.services.paperless = {
    enable = lib.mkEnableOption "paperless-ng service";
    clientId = lib.mkOption {
      type = lib.types.str;
      default = "paperless";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "paperless.girl.pp.ua";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "paperless.nix-infra";
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 16008;
    };
  };
  config = lib.mkIf cfg.services.paperless.enable {
    services.paperless = {
      enable = true;

      inherit (cfg.services.paperless) domain port;

      passwordFile = config.sops.secrets."paperless/password".path;
      environmentFile = config.sops.templates."paperless.env".path;

      database.createLocally = true;
      configureTika = true;
    };

    sops = {
      secrets."paperless/secretKey" = { };
      secrets."paperless/password" = { };
      secrets."paperless/clientSecret" = { };
      templates."paperless.env".content =
        let
          trusted = lib.concatStringsSep "," [
            "https://${config.cfg.services.paperless.domain}"
            "https://${config.cfg.services.paperless.intraDomain}"
            "http://${config.cfg.services.paperless.intraDomain}"
          ];
        in
        ''
          PAPERLESS_SECRET_KEY=${config.sops.placeholder."paperless/secretKey"}

          PAPERLESS_COOKIE_PREFIX=paperless0

          PAPERLESS_ALLOWED_HOSTS=${trusted}
          PAPERLESS_CORS_ALLOWED_HOSTS=${trusted}
          PAPERLESS_CSRF_TRUSTED_ORIGINS=${trusted}

          PAPERLESS_TRUSTED_PROXIES=${
            lib.concatStringsSep "," [
              "127.0.0.1"
              "::1"
              # dell-sv
              "fd7a:115c:a1e0::2901:2214"
              "100.64.0.2"
              # oci2
              "2603:c020:800c:9c7f:0:fe:fe:2"
              "144.24.178.67"
              "fd7a:115c:a1e0::2501:5a59"
              "100.64.0.102"
            ]
          }

          PAPERLESS_APPS=allauth.socialaccount.providers.openid_connect
          PAPERLESS_SOCIALACCOUNT_PROVIDERS=${
            builtins.toJSON {
              openid_connect = {
                OAUTH_PKCE_ENABLED = true;
                APPS = [
                  {
                    provider_id = "kanidm";
                    name = "Girlcock";
                    client_id = "paperless";
                    secret = config.sops.placeholder."paperless/clientSecret";
                    settings = {
                      server_url = idp.oidc_discovery;
                      fetch_userinfo = true;
                      oauth_pkce_enabled = true;
                      token_auth_method = "client_secret_basic";
                    };
                  }
                ];
              };
            }
          }

          PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS=true
          PAPERLESS_SOCIAL_AUTO_SIGNUP=true
          PAPERLESS_DISABLE_REGULAR_LOGIN=true
          PAPERLESS_REDIRECT_LOGIN_TO_SSO=true
          PAPERLESS_ACCOUNT_SESSION_REMEMBER=false
        '';
    };

    services.caddy.virtualHosts."http://${cfg.services.paperless.intraDomain}" = {
      extraConfig = ''
        import encode

        header {
          X-Robots-Tag "noindex, nofollow"
        }

        @forbidden {
          path /admin
        }
        error @forbidden 404

        handle_path /static/* {
          root * ${config.services.paperless.package}/lib/paperless-ngx/static
          file_server
        }

        reverse_proxy http://127.0.0.1:${toString config.services.paperless.port}
      '';
    };
  };
}
