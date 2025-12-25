{
  inputs,
  config,
  pkgs,
  lib,
  root,
  secrets,
  ...
}:
let
  cfg-svc = config.nix-infra.svc;
  cfg = cfg-svc.kanidm;
in
{
  options.nix-infra.svc.kanidm = {
    enable = lib.mkEnableOption "kanidm";
    port = lib.mkOption {
      type = lib.types.int;
      default = 16021;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "sso.girl.pp.ua";
    };
  };
  config = lib.mkIf cfg.enable {
    services.kanidm = {
      enableServer = true;
      package = pkgs.kanidm_1_8.withSecretProvisioning;
      serverSettings = {
        inherit (cfg) domain;
        tls_key = config.sops.secrets."kanidm_tls_key".path;
        tls_chain = config.sops.secrets."kanidm_tls_chain".path;
        origin = "https://${cfg.domain}";
        bindaddress = "127.0.0.1:${toString cfg.port}";
        trust_x_forward_for = true;
      };
      enableClient = true;
      clientSettings = {
        uri = "https://127.0.0.1:${toString cfg.port}";
        ca_path = config.sops.secrets."kanidm_tls_chain".path;
      };
      provision = {
        enable = true;
        autoRemove = true;
        instanceUrl = "https://localhost:${toString cfg.port}";

        persons = {
          grfgh = {
            displayName = "Luna";
            mailAddresses = [
              "luna.prasol@proton.me"
              "prasol258@gmail.com"
            ];
            groups = [
              "authtest.access"
              "oracle-cloud-infrastructure.access"
              "nextcloud.access"
              "paperless.access"
              "immich.access"
              "immich.role.admin"
            ];
          };
          niko = {
            displayName = "Niko";
            mailAddresses = [ "nyanbinary@tutamail.com" ];
            groups = [ ];
          };
          lucy = {
            displayName = "Lucy";
            mailAddresses = [ secrets.lucy.email ];
            groups = [
              "nextcloud.access"
              "immich.access"
              "immich.role.user"
            ];
          };
          svitlana = {
            displayName = "Svitlana";
            mailAddresses = [ secrets.svitlana.email ];
            groups = [
              "nextcloud.access"
              "paperless.access"
              "immich.access"
              "immich.role.user"
            ];
          };
        };

        groups."authtest.access" = { };
        systems.oauth2.${cfg-svc.oauth2_proxy.client_id} = {
          displayName = "oauth2-proxy";
          imageFile = "${root}/assets/sso-images/oauth2-proxy.svg";
          originLanding = "https://authtest.girl.pp.ua/";

          basicSecretFile = config.sops.secrets."kanidm.oauth2_proxy/clientSecret".path;
          originUrl = lib.map (domain: "https://${domain}${cfg-svc.oauth2_proxy.urlPrefix}/callback") [
            "authtest.girl.pp.ua"
          ];

          preferShortUsername = true;
          scopeMaps =
            let
              scope = [
                "profile"
                "email"
                "groups"
                "openid"
              ];
            in
            {
              "authtest.access" = scope;
            };
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup = {
              "authtest.access" = [ "authtest_access" ];
            };
          };
        };

        groups."oracle-cloud-infrastructure.access" = { };
        systems.oauth2."oracle-cloud-infrastructure" = {
          displayName = "Oracle Cloud Infrastructure";
          imageFile = "${root}/assets/sso-images/oracle-cloud-infrastructure.svg";
          originLanding = "https://cloud.oracle.com/?tenant=${secrets.ociTenancy.tenancyName}&region=${secrets.ociTenancy.tenancyRegion}";

          basicSecretFile = config.sops.secrets."ociTenancy/clientSecret".path;
          allowInsecureClientDisablePkce = true; # Oracle Cloud does not support PKCE
          originUrl = [
            "https://${secrets.ociTenancy.identityDomain}/oauth2/v1/social/callback"
            "https://${secrets.ociTenancy.identityDomain}:443/oauth2/v1/social/callback"
          ];

          preferShortUsername = true;
          scopeMaps."oracle-cloud-infrastructure.access" = [
            "openid"
            "email"
            "profile"
          ];
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup."oracle-cloud-infrastructure.access" = [
              "oracle_cloud_infrastructure_access"
            ];
          };
        };

        groups."nextcloud.access" = { };
        systems.oauth2.${cfg-svc.nextcloud.client_id} = {
          displayName = "Nextcloud";
          imageFile = "${root}/assets/sso-images/nextcloud.svg";
          originLanding = "https://${cfg-svc.nextcloud.domain}/";

          basicSecretFile = config.sops.secrets."kanidm.nextcloud/clientSecret".path;
          enableLegacyCrypto = true; # Nextcloud does not support ES256
          originUrl = [
            "https://${cfg-svc.nextcloud.domain}/apps/user_oidc/code"
            "https://${cfg-svc.nextcloud.intraDomain}/apps/user_oidc/code"
          ];

          preferShortUsername = true;
          scopeMaps."nextcloud.access" = [
            "openid"
            "email"
            "profile"
            "groups"
          ];
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup."nextcloud.access" = [ "nextcloud_access" ];
          };
        };

        groups."paperless.access" = { };
        # groups."paperless.admin" = { };
        systems.oauth2.${cfg-svc.paperless.client_id} = {
          displayName = "Paperless-ngx";
          imageFile = "${root}/assets/sso-images/paperless-ngx.svg";
          originLanding = "https://${cfg-svc.paperless.domain}/";

          basicSecretFile = config.sops.secrets."kanidm.paperless/clientSecret".path;
          originUrl = [
            "https://${cfg-svc.paperless.domain}/accounts/oidc/kanidm/login/callback/"
            "https://${cfg-svc.paperless.intraDomain}/accounts/oidc/kanidm/login/callback/"
          ];

          preferShortUsername = true;
          scopeMaps."paperless.access" = [
            "profile"
            "email"
            "groups"
            "openid"
          ];
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup."paperless.access" = [ "paperless_access" ];
            # valuesByGroup."paperless.admin" = [ "paperless_admin" ];
          };
        };

        groups."immich.access" = { };
        groups."immich.role.user" = { };
        groups."immich.role.admin" = { };
        systems.oauth2.${cfg-svc.immich.client_id} = {
          displayName = "Immich";
          imageFile = "${root}/assets/sso-images/immich.svg";
          originLanding = "https://${cfg-svc.immich.domain}/";

          basicSecretFile = config.sops.secrets."kanidm.immich/clientSecret".path;
          originUrl = [
            "https://${cfg-svc.immich.domain}/auth/login"
            "https://${cfg-svc.immich.domain}/user-settings"
            "https://${cfg-svc.immich.domain}/api/oauth/mobile-redirect"
            "https://${cfg-svc.immich.intraDomain}/auth/login"
            "https://${cfg-svc.immich.intraDomain}/user-settings"
            "https://${cfg-svc.immich.intraDomain}/api/oauth/mobile-redirect"
            "app.immich:///oauth-callback"
          ];

          preferShortUsername = true;
          scopeMaps."immich.access" = [
            "openid"
            "email"
            "profile"
          ];
          claimMaps = {
            groups = {
              joinType = "array";
              valuesByGroup."immich.access" = [ "immich_access" ];
            };
            immich_role = {
              joinType = "array";
              valuesByGroup."immich.role.user" = [ "user" ];
              valuesByGroup."immich.role.admin" = [ "admin" ];
            };
          };

          # TODO: support quota
        };
      };
    };

    services.caddy.virtualHosts = {
      ${cfg.domain} = {
        extraConfig = ''
          import encode
          import norobot
          import waf
          reverse_proxy https://127.0.0.1:${toString cfg.port} {
            transport http {
              tls_trust_pool file ${config.sops.secrets."kanidm_caddy_tls_chain".path}
            }
          }
        '';
      };
    };

    sops.secrets =
      let
        kanidmSecret = {
          mode = "0400";
          owner = "kanidm";
          group = "kanidm";
        };
      in
      {
        "ociTenancy/clientSecret" = kanidmSecret;
        "kanidm.oauth2_proxy/clientSecret" = kanidmSecret // {
          key = "oauth2_proxy/clientSecret";
        };
        "kanidm.nextcloud/clientSecret" = kanidmSecret // {
          key = "nextcloud/clientSecret";
        };
        "kanidm.paperless/clientSecret" = kanidmSecret // {
          key = "paperless/clientSecret";
        };
        "kanidm.immich/clientSecret" = kanidmSecret // {
          key = "immich/clientSecret";
        };
        "kanidm_tls_key" = kanidmSecret // {
          sopsFile = "${inputs.secrets}/certs/tls_key.sops.pem";
          format = "binary";
        };
        "kanidm_tls_chain" = kanidmSecret // {
          sopsFile = "${inputs.secrets}/certs/tls_chain.sops.pem";
          format = "binary";
        };
        "kanidm_caddy_tls_chain" = {
          sopsFile = "${inputs.secrets}/certs/tls_chain.sops.pem";
          format = "binary";
          mode = "0400";
          owner = "caddy";
          group = "caddy";
        };
      };
  };
}
