{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.karakeep;
  idp = libx.idp {
    inherit (config.polaris.services.kanidm) domain;
    inherit (cfg) client_id;
  };
in
{
  options.polaris.services.karakeep = {
    enable = lib.mkEnableOption "karakeep";
    port = lib.mkOption {
      type = lib.types.port;
      default = 16140;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "keep.lunya.cc";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "karakeep";
    };
    roleClaim = lib.mkOption {
      type = lib.types.str;
      default = "karakeep_role";
    };
  };

  config = lib.mkIf cfg.enable {
    polaris.services.oauth2_proxy.enable = true;

    services.karakeep = {
      enable = true;
      package = pkgs.karakeep.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          # sync user role from an oidc claim login
          ./oidc-role-claim.patch
        ];
      });
      extraEnvironment = {
        PORT = toString cfg.port;
        NEXTAUTH_URL = "https://${cfg.domain}";
        DISABLE_NEW_RELEASE_CHECK = "true";
        DISABLE_PASSWORD_AUTH = "true";
        OAUTH_AUTO_REDIRECT = "true";
        OAUTH_PROVIDER_NAME = "Girlcock";
        OAUTH_WELLKNOWN_URL = idp.oidc_discovery;
        OAUTH_CLIENT_ID = cfg.client_id;
        OAUTH_ID_TOKEN_SIGNED_RESPONSE_ALG = "ES256";
        OAUTH_ROLE_CLAIM = cfg.roleClaim;
      };
      environmentFile = config.sops.templates."karakeep.env".path;
    };

    systemd.services.karakeep-web.environment.HOSTNAME = "127.0.0.1";

    sops.secrets."karakeep/clientSecret" = { };
    sops.templates."karakeep.env" = {
      mode = "0400";
      owner = "karakeep";
      group = "karakeep";
      content = ''
        OAUTH_CLIENT_SECRET=${config.sops.placeholder."karakeep/clientSecret"}
      '';
    };

    services.caddy.virtualHosts."${cfg.domain}" = {
      extraConfig = ''
        import encode
        import norobot
        header /_next/static/* >Cache-Control "public, max-age=31536000, immutable"

        import oauth2_proxy_handle

        @admin {
          path /admin /admin/* /api/v1/admin/*
          path_regexp ^/api/trpc/(.*,)?(admin\.[^,]+|users\.(list|delete)|invites\.(create|list|revoke|resend))(,|$)
        }
        handle @admin {
          import oauth2_proxy_secure_external "karakeep_admin"
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }

        reverse_proxy 127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
