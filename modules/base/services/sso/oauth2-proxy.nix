{
  config,
  lib,
  libx,
  ...
}:
let
  inherit (config) cfg;
  idp = libx.idp {
    domain = cfg.services.kanidm.domain;
    client_id = cfg.services.oauth2_proxy.clientID;
  };
in
{
  options = {
    cfg.services.oauth2_proxy = {
      enable = lib.mkEnableOption "oauth2_proxy";
      port = lib.mkOption {
        type = lib.types.int;
        default = 16022;
      };
      urlPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/_oauth2_proxy";
      };
      clientID = lib.mkOption {
        type = lib.types.str;
        default = "oauth2-proxy";
      };
    };
  };

  config = lib.mkIf cfg.services.oauth2_proxy.enable {
    services.oauth2-proxy = {
      enable = true;

      keyFile = config.sops.secrets."oauth2_proxy/keyFile".path;

      httpAddress = "http://127.0.0.1:${toString cfg.services.oauth2_proxy.port}";
      proxyPrefix = cfg.services.oauth2_proxy.urlPrefix;
      reverseProxy = true;
      approvalPrompt = "auto";
      setXauthrequest = true;
      # redirectURL = "https://oauth2.girl.pp.ua/oauth2/callback";

      provider = "oidc";
      inherit (cfg.services.oauth2_proxy) clientID;
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

    systemd.services.oauth2-proxy.after = lib.optionals cfg.services.kanidm.enable [
      "kanidm.service"
    ];

    services.caddy.extraConfig = ''
      (oauth2_proxy) {
        handle ${cfg.services.oauth2_proxy.urlPrefix}/* {
          reverse_proxy http://127.0.0.1:${toString cfg.services.oauth2_proxy.port} {
            header_up X-Real-IP {remote_host}
			      header_up X-Forwarded-Uri {uri}
          }
        }
        handle {
          forward_auth http://127.0.0.1:${toString cfg.services.oauth2_proxy.port} {
            uri ${cfg.services.oauth2_proxy.urlPrefix}/auth?allowed_groups={args[0]}
            header_up X-Real-IP {remote_host}
            @error status 401
            handle_response @error {
              redir * ${cfg.services.oauth2_proxy.urlPrefix}/sign_in?rd={scheme}://{host}{uri}
            }
          }
        }
      }
    '';

    sops.secrets."oauth2_proxy/keyFile" = {
      mode = "0400";
      owner = "oauth2-proxy";
      group = "oauth2-proxy";
    };
  };
}
