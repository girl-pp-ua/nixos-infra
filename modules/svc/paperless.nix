{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.nix-infra.svc.paperless;
  cfg-svc = config.nix-infra.svc;
  idp = libx.idp {
    inherit (cfg-svc.kanidm) domain;
    inherit (cfg) client_id;
  };
in
{
  options.nix-infra.svc.paperless = {
    enable = lib.mkEnableOption "paperless-ng service";
    client_id = lib.mkOption {
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

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;

      package = pkgs.paperless-ngx.overrideAttrs (prev: {
        # XXX: build failure
        disabledTests = prev.disabledTests ++ [
          "test_consume_file"
          "test_mac_write"
          "test_slow_write_and_move"
          "test_slow_write_incomplete"
          "test_slow_write_pdf"
        ];
      });

      # TODO: fix patch
      # package = pkgs.paperless-ngx.overrideAttrs (old: {
      #   doInstallCheck = false;
      #   patches = (old.patches or [ ]) ++ [
      #     # oidc is mostly unusable without this feature
      #     # https://github.com/paperless-ngx/paperless-ngx/discussions/7307#discussion-6972082
      #     # https://github.com/paperless-ngx/paperless-ngx/pull/7655
      #     # ./paperless-oidc.patch
      #   ];
      # });

      inherit (cfg) domain port;

      database.createLocally = true;
      configureTika = true;

      passwordFile = config.sops.secrets."paperless/password".path;
      environmentFile = config.sops.templates."paperless.env".path;

      settings = {
        PAPERLESS_URL = "https://${cfg.domain}";

        PAPERLESS_OCR_LANGUAGE = "eng+ukr+pol";
        PAPERLESS_OCR_LANGUAGES = "ukr pol";
        PAPERLESS_OCR_DESKEW = "false"; # fucks up some documents
        PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
          # this is okay since Paperless saves the original documents
          invalidate_digital_signatures = true;
        };

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

        PAPERLESS_SOCIAL_ACCOUNT_DEFAULT_GROUPS = "New Users";
        PAPERLESS_ACCOUNT_DEFAULT_GROUPS = "New Users";
        # PAPERLESS_SOCIALACCOUNT_DEFAULT_PERMISSIONS = "view_uisettings";
        # PAPERLESS_SOCIALACCOUNT_ADMIN_GROUPS = "paperless.admin@${cfg-svc.kanidm.domain}";
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

    services.caddy.virtualHosts."http://${cfg.intraDomain}" = {
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode
        import norobot
        import waf
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
