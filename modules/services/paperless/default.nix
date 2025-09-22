{
  config,
  pkgs,
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
      package = pkgs.paperless-ngx.overrideAttrs (old: {
        doInstallCheck = false;
        patches = (old.patches or [ ]) ++ [
          # oidc is mostly unusable without this feature
          # https://github.com/paperless-ngx/paperless-ngx/discussions/7307#discussion-6972082
          # https://github.com/paperless-ngx/paperless-ngx/pull/7655
          ./paperless-oidc.patch
        ];
      });

      inherit (cfg.services.paperless) domain port;

      database.createLocally = true;
      configureTika = true;

      passwordFile = config.sops.secrets."paperless/password".path;
      environmentFile = config.sops.templates."paperless.env".path;

      settings = {
        PAPERLESS_URL = "https://${config.cfg.services.paperless.domain}";

        PAPERLESS_TRUSTED_PROXIES = [
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
        ];

        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";

        PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = true;
        PAPERLESS_SOCIAL_AUTO_SIGNUP = true;
        PAPERLESS_DISABLE_REGULAR_LOGIN = true;
        PAPERLESS_REDIRECT_LOGIN_TO_SSO = true;
        PAPERLESS_ACCOUNT_SESSION_REMEMBER = false;

        PAPERLESS_SOCIALACCOUNT_DEFAULT_PERMISSIONS = "view_uisettings";
        PAPERLESS_SOCIALACCOUNT_ADMIN_GROUPS = "paperless.admin@${cfg.services.kanidm.domain}";
      };
    };

    sops =
      let
        owned = {
          owner = "paperless";
          group = "paperless";
          mode = "0440";
        };
      in
      {
        secrets."paperless/password" = owned;

        secrets."paperless/secretKey" = { };
        secrets."paperless/clientSecret" = { };
        templates."paperless.env" = owned // {
          content = ''
            PAPERLESS_SECRET_KEY=${config.sops.placeholder."paperless/secretKey"}
            PAPERLESS_SOCIALACCOUNT_PROVIDERS=${
              builtins.toJSON {
                openid_connect = {
                  OAUTH_PKCE_ENABLED = true;
                  SCOPE = [
                    "profile"
                    "email"
                    "groups"
                    "openid"
                  ];
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
          '';
        };
      };

    services.caddy.virtualHosts."http://${cfg.services.paperless.intraDomain}" = {
      serverAliases = [
        "http://${cfg.services.paperless.domain}"
      ];
      extraConfig = ''
        import encode

        header {
          X-Robots-Tag "noindex, nofollow"
        }

        # @forbidden {
        #   path /admin
        # }
        # error @forbidden 404

        # handle_path /static/* {
        #   root * ${config.services.paperless.package}/lib/paperless-ngx/static
        #   file_server
        # }

        reverse_proxy http://127.0.0.1:${toString config.services.paperless.port}
      '';
    };
  };
}
