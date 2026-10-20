{ config, lib, ... }:
let
  cfg = config.polaris.services.ntfy;
in
{
  options.polaris.services.ntfy = {
    enable = lib.mkEnableOption "ntfy-sh";
    port = lib.mkOption {
      type = lib.types.int;
      default = 16002;
    };
    metricsPort = lib.mkOption {
      type = lib.types.int;
      default = 16003;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "ntfy.girl.pp.ua";
    };
  };
  config = lib.mkIf cfg.enable {
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${cfg.domain}";
        upstream-base-url = "https://ntfy.sh";
        listen-http = "127.0.0.1:${toString cfg.port}";
        behind-proxy = true;
        # enable-signup = true;
        # enable-login = true;
        enable-reservations = true;
        enable-metrics = true;
        metrics-listen-http = ":${toString cfg.metricsPort}";
      };
    };
    polaris.services.monitoring.exports.ntfy.port = cfg.metricsPort;

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        import encode
        import norobot
        handle_path /docs/* {
          redir https://docs.ntfy.sh{path} permanent
        }
        reverse_proxy localhost:${toString cfg.port}
      '';
    };
  };
}
