{ config, lib, ... }:
let
  cfg = config.cfg;
in {
  options = {
    cfg.services.kanidm = {
      enable = lib.mkEnableOption "kanidm";
      port = lib.mkOption {
        type = lib.types.int;
        default = 16012;
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
    };

    services.caddy.virtualHosts = {
      ${cfg.services.kanidm.domain} = {
        extraConfig = ''
          reverse_proxy https://127.0.0.1:${toString cfg.services.kanidm.port} {
            transport http {
              tls_trusted_ca_certs ${cfg.secrets.selfSignedCert.tls_chain}
            }
          }
        '';
      };
    };
  };
}