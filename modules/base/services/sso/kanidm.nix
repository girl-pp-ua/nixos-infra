{
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
        inherit (cfg.secrets.selfSignedCert) tls_key tls_chain;
        inherit (cfg.services.kanidm) domain;
        origin = "https://${cfg.services.kanidm.domain}";
        bindaddress = "127.0.0.1:${toString cfg.services.kanidm.port}";
        trust_x_forward_for = true;
      };
      enableClient = true;
      clientSettings = {
        uri = "https://127.0.0.1:${toString cfg.services.kanidm.port}";
        ca_path = cfg.secrets.selfSignedCert.tls_chain;
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
              "fwauthtest1.access"
              "uptime-kuma.access"
              "oracle-cloud-infrastructure.access"
            ];
          };
          niko = {
            displayName = "niko";
            mailAddresses = [ "nyanbinary@tutamail.com" ];
            groups = [
              "fwauthtest1.access"
              "uptime-kuma.access"
              "oracle-cloud-infrastructure.access"
            ];
          };
        };

        # FIXME: currently, enabling ANY of oauth2-proxy groups allows access to ALL services proxied by oauth2-proxy
        groups."fwauthtest1.access" = { };
        groups."uptime-kuma.access" = { };
        systems.oauth2."oauth2-proxy" = {
          displayName = "oauth2-proxy";
          preferShortUsername = true;

          # FIXME: BAD IDEA! secret is exposed in /nix/store
          basicSecretFile = pkgs.writeText "this_is_bad_1" cfg.secrets.oauth2_proxy.clientSecret;

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
              "fwauthtest1.access" = scope;
              "uptime-kuma.access" = scope;
            };

          claimMaps.groups = {
            joinType = "array";
            valuesByGroup."fwauthtest1.access" = [ "fwauthtest1_access" ];
            valuesByGroup."uptime-kuma.access" = [ "uptime_kuma_access" ];
          };
        };

        groups."oracle-cloud-infrastructure.access" = { };
        systems.oauth2."oracle-cloud-infrastructure" = {
          displayName = "Oracle Cloud Infrastructure";
          preferShortUsername = true;

          # Oracle Cloud does not support PKCE
          allowInsecureClientDisablePkce = true;

          # FIXME: BAD IDEA! secret is exposed in /nix/store
          basicSecretFile = pkgs.writeText "this_is_bad_2" cfg.secrets.ociTenancy.clientSecret;

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
      };
    };

    services.caddy.virtualHosts = {
      ${cfg.services.kanidm.domain} = {
        extraConfig = ''
          reverse_proxy https://127.0.0.1:${toString cfg.services.kanidm.port} {
            transport http {
              tls_trust_pool file ${cfg.secrets.selfSignedCert.tls_chain}
            }
          }
        '';
      };
    };
  };
}
