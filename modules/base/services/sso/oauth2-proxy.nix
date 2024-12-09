{ config, lib, ... }:
let
  cfg = config.cfg;
  idp = import ./../../../../lib/oidc-kamidm.nix {
    domain = cfg.services.oauth2_proxy.authDomain;
    client_id = cfg.services.oauth2_proxy.clientID;
  };
in {
  options = {
    cfg.services.oauth2_proxy = {
      enable = lib.mkEnableOption "oauth2_proxy" // {
        # if canidm is enabled, oauth2_proxy will be enabled by default
        default = cfg.services.kanidm.enable;
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 16022;
      };
      urlPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/_oauth2";
      };
      clientID = lib.mkOption {
        type = lib.types.str;
        default = "oauth2-proxy";
      };
      authDomain = lib.mkOption {
        type = lib.types.str;
        default = cfg.services.kanidm.domain;
      };
    };
  };

  config = lib.mkIf cfg.services.oauth2_proxy.enable {
    # TODO

    services.oauth2-proxy = {
      # TODO fix kanidm OAuth2
      enable = true;

      httpAddress = "http://127.0.0.1:${toString cfg.services.oauth2_proxy.port}";
      proxyPrefix = cfg.services.oauth2_proxy.urlPrefix;
      reverseProxy = true;
      approvalPrompt = "auto";
      setXauthrequest = true;
      # redirectURL = "https://oauth2.girl.pp.ua/oauth2/callback";

      provider = "oidc";
      inherit (cfg.services.oauth2_proxy) clientID;
      inherit (cfg.secrets.oauth2_proxy) clientSecret;
      oidcIssuerUrl = idp.oidc_issuer_uri;
      loginURL = idp.api_auth; # ui?
      redeemURL = idp.token_endpoint;
      validateURL = idp.rfc7662_token_introspection;
      profileURL = idp.oidc_user_info;

      email.domains = [ "*" ];
      scope = "openid profile email";

      cookie.secret = cfg.secrets.oauth2_proxy.cookieSecret;

      extraConfig = {
        provider-display-name = "Kanidm";
        # skip-provider-button = true;
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
          reverse_proxy http://127.0.0.1:${toString cfg.services.oauth2_proxy.port}
        }
        handle {
          forward_auth http://127.0.0.1:${toString cfg.services.oauth2_proxy.port} {
            uri ${cfg.services.oauth2_proxy.urlPrefix}/auth
            @bad status 4xx
            handle_response @bad {
              redir * ${cfg.services.oauth2_proxy.urlPrefix}/start
            }
          }
        }
      }
    '';

    services.caddy.virtualHosts."fwauthtest1.girl.pp.ua".extraConfig = ''
      import oauth2_proxy
      respond "OK"
    '';
  };
}