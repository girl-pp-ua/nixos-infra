{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.cfg;
in
{
  options = {
    cfg.services.kanidm = {
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
  };
  config = lib.mkIf cfg.services.kanidm.enable {
    services.kanidm = {
      enableServer = true;
      package = pkgs.kanidm.withSecretProvisioning;
      serverSettings = {
        inherit (cfg.services.kanidm) domain;
        tls_key = config.sops.secrets."kanidm_tls_key".path;
        tls_chain = config.sops.secrets."kanidm_tls_chain".path;
        origin = "https://${cfg.services.kanidm.domain}";
        bindaddress = "127.0.0.1:${toString cfg.services.kanidm.port}";
        trust_x_forward_for = true;
      };
      enableClient = true;
      clientSettings = {
        uri = "https://127.0.0.1:${toString cfg.services.kanidm.port}";
        ca_path = config.sops.secrets."kanidm_tls_chain".path;
      };
      provision = {
        enable = true;
        autoRemove = true;
        instanceUrl = "https://localhost:${toString cfg.services.kanidm.port}";

        persons = {
          grfgh = {
            displayName = "grfgh";
            mailAddresses = [ "prasol258@gmail.com" ];
            groups = [
              "oauth2-proxy.access"
              "oracle-cloud-infrastructure.access"
              "nextcloud.access"
            ];
          };
          niko = {
            displayName = "niko";
            mailAddresses = [ "nyanbinary@tutamail.com" ];
            groups = [
              "oauth2-proxy.access"
              "oracle-cloud-infrastructure.access"
            ];
          };
        };

        # TODO: more granular access control
        # currently, only gates uptime-kuma access
        groups."oauth2-proxy.access" = { };
        systems.oauth2."oauth2-proxy" = {
          displayName = "oauth2-proxy";
          preferShortUsername = true;

          basicSecretFile = config.sops.secrets."oauth2_proxy/clientSecret".path;

          originLanding = "https://fwauthtest1.girl.pp.ua/";
          originUrl =
            let
              mkOriginUrl = domain: "https://${domain}${cfg.services.oauth2_proxy.urlPrefix}/callback";
            in
            [
              (mkOriginUrl "fwauthtest1.girl.pp.ua")
              (mkOriginUrl "uptime.girl.pp.ua")
            ];

          scopeMaps =
            let
              scope = [
                "openid"
                "email"
                "profile"
              ];
            in
            {
              "oauth2-proxy.access" = scope;
            };

          claimMaps.groups = {
            joinType = "array";
            valuesByGroup."oauth2-proxy.access" = [
              "oauth2_proxy_access"
            ];
          };
        };

        groups."oracle-cloud-infrastructure.access" = { };
        systems.oauth2."oracle-cloud-infrastructure" = {
          displayName = "Oracle Cloud Infrastructure";
          preferShortUsername = true;

          # Oracle Cloud does not support PKCE
          allowInsecureClientDisablePkce = true;

          basicSecretFile = config.sops.secrets."ociTenancy/clientSecret".path;

          originLanding = "https://cloud.oracle.com/?tenant=${cfg.secrets.ociTenancy.tenancyName}&region=${cfg.secrets.ociTenancy.tenancyRegion}";
          originUrl = [
            "https://${cfg.secrets.ociTenancy.identityDomain}/oauth2/v1/social/callback"
            "https://${cfg.secrets.ociTenancy.identityDomain}:443/oauth2/v1/social/callback"
          ];

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
        systems.oauth2."nextcloud" = {
          displayName = "Nextcloud";
          preferShortUsername = true;

          basicSecretFile = config.sops.secrets."nextcloud/clientSecret".path;

          # Nextcloud does not support ES256
          enableLegacyCrypto = true;

          originLanding = "http://${cfg.services.nextcloud.domain}/";
          originUrl = [
            "https://${cfg.services.nextcloud.domain}/apps/oidc_login/oidc"
            "https://${cfg.services.nextcloud.intraDomain}/apps/oidc_login/oidc"
            # "http://${cfg.services.nextcloud.domain}/apps/oidc_login/oidc"
          ];

          scopeMaps."nextcloud.access" = [
            "profile"
            "email"
            "groups"
            "openid"
          ];

          # supplementaryScopeMaps."nextcloud.admin" = [
          #   "nextcloudadmin"
          # ];

          claimMaps.groups = {
            joinType = "array";
            valuesByGroup."nextcloud.access" = [
              "nextcloud_access"
            ];
          };
        };
      };
    };

    services.caddy.virtualHosts = {
      ${cfg.services.kanidm.domain} = {
        extraConfig = ''
          reverse_proxy https://127.0.0.1:${toString cfg.services.kanidm.port} {
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
        "oauth2_proxy/clientSecret" = kanidmSecret;
        "nextcloud/clientSecret" = kanidmSecret;
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
