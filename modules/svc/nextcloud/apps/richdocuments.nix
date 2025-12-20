{ config, lib, ... }:
let
  cfg = config.nix-infra.svc.nextcloud.app.richdocuments;
  cfg-nextcloud = config.nix-infra.svc.nextcloud;
in
{
  options.nix-infra.svc.nextcloud.app.richdocuments = {
    enable = lib.mkEnableOption "collabora office app" // {
      default = cfg-nextcloud.enable;
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 9980;
    };
  };

  config = lib.mkIf cfg.enable {
    services.collabora-online = {
      enable = true;
      inherit (cfg) port;
      aliasGroups = [
        {
          host = "https://cloud.girl.pp.ua:443";
          aliases = [ ];
        }
      ];
      settings = {
        server_name = cfg-nextcloud.domain;
        ssl = {
          enable = false;
          termination = true;
        };
        net = {
          listen = "loopback";
          post_allow.host = [ "::1" ];
        };
        storage.wopi = {
          "@allow" = true;
          # XXX: might be incorrect for multiple hosts
          host = [ cfg-nextcloud.domain ];
        };
      };
    };

    services.nextcloud = {
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          richdocuments
          ;
      };
      extraOCCCommands = ''
        occ config:app:set richdocuments public_wopi_url --value "https://${cfg-nextcloud.domain}"
        occ config:app:set richdocuments wopi_callback_url --value "http://${cfg-nextcloud.intraDomain}"
        occ config:app:set richdocuments wopi_url --value "http://[::1]:${cfg.port}"
        occ config:app:set richdocuments doc_format --value "" # use opendocument formats
        occ config:app:set richdocuments wopi_allowlist --value "${
          lib.concatStringsSep "," [
            "127.0.0.1"
            "::1"
            "fd7a:115c:a1e0::/48" # tailscale
          ]
        }"
        occ richdocuments:activate-config
      '';
    };

    services.caddy.virtualHosts."http://${cfg-nextcloud.domain}" = {
      extraConfig = lib.mkBefore ''
        @collabora-public path /hosting/capabilities /hosting/discovery /cool/* /browser/*
        handle @collabora-public {
          reverse_proxy http://[::1]:${cfg.port}
        }
      '';
    };

  };
}
