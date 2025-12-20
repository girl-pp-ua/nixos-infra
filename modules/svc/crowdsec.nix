{ config, lib, ... }:
let
  cfg = config.nix-infra.svc.crowdsec;
in
{
  options.nix-infra.svc.crowdsec = {
    enable = lib.mkEnableOption "crowdsec" // {
      default = true;
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 8390;
    };
  };

  config = lib.mkIf cfg.enable {
    security.auditd = {
      enable = true;
    };

    services.crowdsec = {
      enable = true;
      autoUpdateService = true;
      settings = {
        console.tokenFile = config.sops.secrets."crowdsec/consoleToken".path;
        general.api.server = {
          listen_uri = "http://[::1]:${builtins.toString cfg.port}";
          trusted_ips = [
            "127.0.0.1"
            "::1"
          ];
        };
      };
      hub = {
        collections = [
          "crowdsecurity/linux"
          "crowdsecurity/postfix"

          "crowdsecurity/appsec-virtual-patching"
          "crowdsecurity/appsec-generic-rules"
          "crowdsecurity/appsec-crs"

          "crowdsecurity/whitelist-good-actors"
          "crowdsecurity/discord-crawler-whitelist"

          "crowdsecurity/auditd"

          "crowdsecurity/base-http-scenarios"
          "crowdsecurity/http-dos"

          "crowdsecurity/caddy"
          "crowdsecurity/nextcloud"
          "gauth-fr/immich"
          "andreasbrett/paperless-ngx"
          "Jgigantino31/ntfy"
        ];
        parsers = [
          "crowdsecurity/sshd-logs"
        ];
        appSecRules = [
          "crowdsecurity/base-config"
        ];
        appSecConfigs = [
          "crowdsecurity/appsec-default"
        ];
        postOverflows = [
          "crowdsecurity/auditd-nix-wrappers-whitelist-process"
        ];
      };
      localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=caddy.service" ];
          labels.type = "syslog";
        }
        {
          filenames = [ "/var/log/audit/*.log" ];
          labels.type = "auditd";
        }
      ];
    };

    services.crowdsec-firewall-bouncer = {
      enable = true;
      registerBouncer.enable = true;
      settings = {
        log_mode = "stdout";
        mode = "nftables";
        blacklists_ipv4 = "crowdsec-blacklists";
        blacklists_ipv6 = "crowdsec6-blacklists";
        nftables = {
          ipv4 = {
            table = "crowdsec";
            chain = "crowdsec-chain";
            enabled = true;
            set-only = true;
          };
          ipv6 = {
            table = "crowdsec6";
            chain = "crowdsec6-chain";
            enabled = true;
            set-only = true;
          };
        };
      };
    };

    networking.nftables.tables = {
      crowdsec = {
        family = "ip";
        content = ''
          set crowdsec-blacklists {
            type ipv4_addr
            flags timeout
          }

          chain crowdsec-chain {
            type filter hook input priority filter; policy accept;
            ip saddr @crowdsec-blacklists drop
          }
        '';
      };
      crowdsec6 = {
        family = "ip6";
        content = ''
          set crowdsec6-blacklists {
            type ipv6_addr
            flags timeout
          }

          chain crowdsec6-chain {
            type filter hook input priority filter; policy accept;
            ip6 saddr @crowdsec6-blacklists drop
          }
        '';
      };
    };

    environment.systemPackages = [
      config.services.crowdsec.package
    ];

    sops.secrets = {
      "crowdsec/consoleToken" = { };
    };
  };
}
