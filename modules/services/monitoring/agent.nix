{ config, lib, ... }:
let
  cfg = config.polaris.services.monitoring.agent;
  cfg-server = config.polaris.services.monitoring.server;
  collector = config.polaris.hosts.${cfg.collector}.internal;
  node = config.services.prometheus.exporters.node;
in
{
  options.polaris.services.monitoring.agent = {
    enable = lib.mkEnableOption "monitoring agent" // {
      default = true;
    };
    collector = lib.mkOption {
      type = lib.types.str;
      default = "amoeba";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
    };

    # only the collector can scrape
    networking.firewall.extraInputRules = ''
      ip saddr ${collector.ipv4} tcp dport ${toString node.port} accept
      ip6 saddr ${collector.ipv6} tcp dport ${toString node.port} accept
    '';

    # logs
    services.fluent-bit = {
      enable = true;
      settings = {
        service.log_level = "warn";
        pipeline = {
          inputs = [
            {
              name = "systemd";
              tag = "journal";
              db = "/var/lib/fluent-bit/journal.db";
              read_from_tail = true;
              strip_underscores = true;
              lowercase = true;
              mem_buf_limit = "8M";
            }
          ];
          filters = [
            # drop debug-level entries
            {
              name = "grep";
              match = "journal";
              exclude = "priority ^7$";
            }
            # keep only the fields we use
            {
              name = "record_modifier";
              match = "journal";
              allowlist_key = [
                "message"
                "priority"
                "systemd_unit"
                "syslog_identifier"
              ];
            }
          ];
          outputs = [
            {
              name = "loki";
              match = "journal";
              host = collector.fqdn;
              port = cfg-server.ingestPort;
              uri = "/insert/loki/api/v1/push";
              compress = "gzip";
              labels = lib.concatStringsSep ", " [
                "host=${config.networking.hostName}"
                "unit=$systemd_unit"
                "identifier=$syslog_identifier"
                "priority=$priority"
              ];
              remove_keys = "systemd_unit, syslog_identifier, priority";
              drop_single_key = "raw";
              retry_limit = 10;
            }
          ];
        };
      };
    };
    systemd.services.fluent-bit.serviceConfig.StateDirectory = "fluent-bit";
  };
}
