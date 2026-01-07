{
  config,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.oauth2_proxy;
  idp = libx.idp {
    inherit (config.polaris.services.kanidm) domain;
    inherit (cfg) client_id;
  };
in
{
  options.polaris.services.oauth2_proxy = {
    enable = lib.mkEnableOption "oauth2_proxy";
    port = lib.mkOption {
      type = lib.types.int;
      default = 16022;
    };
    urlPrefix = lib.mkOption {
      type = lib.types.str;
      default = "/_oauth2_proxy";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "oauth2-proxy";
    };
  };

  config = lib.mkIf cfg.enable {
    services.oauth2-proxy = {
      enable = true;

      keyFile = config.sops.templates."oauth2_proxy.keyFile".path;

      httpAddress = "http://127.0.0.1:${toString cfg.port}";
      proxyPrefix = cfg.urlPrefix;
      reverseProxy = true;
      approvalPrompt = "auto";
      setXauthrequest = true;
      # redirectURL = "https://oauth2.girl.pp.ua/oauth2/callback";

      provider = "oidc";
      clientID = cfg.client_id;
      oidcIssuerUrl = idp.oidc_issuer_uri;
      loginURL = idp.api_auth; # ui?
      redeemURL = idp.token_endpoint;
      validateURL = idp.rfc7662_token_introspection;
      profileURL = idp.oidc_user_info;

      email.domains = [ "*" ];
      scope = "openid profile email";

      extraConfig = {
        provider-display-name = "Kanidm";
        skip-provider-button = true;
        code-challenge-method = "S256";
        set-authorization-header = true;
        pass-access-token = true;
        skip-jwt-bearer-tokens = true;
        upstream = "static://202";
      };
    };

    systemd.services.oauth2-proxy.after = lib.optionals config.polaris.services.kanidm.enable [
      "kanidm.service"
    ];

    services.caddy.extraConfig = ''
      (oauth2_proxy) {
        handle ${cfg.urlPrefix}/* {
          reverse_proxy http://127.0.0.1:${toString cfg.port} {
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-Uri {uri}
          }
        }
        handle {
          forward_auth http://127.0.0.1:${toString cfg.port} {
            uri ${cfg.urlPrefix}/auth?allowed_groups={args[0]}
            header_up X-Real-IP {remote_host}
            @error status 401
            handle_response @error {
              redir * ${cfg.urlPrefix}/sign_in?rd={scheme}://{host}{uri}
            }
          }
        }
      }
    '';

    sops =
      let
        perms = {
          mode = "0400";
          owner = "oauth2-proxy";
          group = "oauth2-proxy";
        };
      in
      {
        secrets."oauth2_proxy/clientSecret" = { };
        secrets."oauth2_proxy/cookieSecret" = { };
        templates."oauth2_proxy.keyFile" = perms // {
          content = ''
            OAUTH2_PROXY_CLIENT_SECRET=${config.sops.placeholder."oauth2_proxy/clientSecret"}
            OAUTH2_PROXY_COOKIE_SECRET=${config.sops.placeholder."oauth2_proxy/cookieSecret"}
          '';
        };
      };
  };
}
