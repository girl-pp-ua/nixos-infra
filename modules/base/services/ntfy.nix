{ config, lib, ... }:
let cfg = config.cfg; in{
  options = {
    cfg.services.ntfy = {
      enable = lib.mkEnableOption "ntfy-sh";
      port = lib.mkOption {
        type = lib.types.int;
        default = 16002;
      };
      domain = lib.mkOption {
        type = lib.types.str;
        default = "ntfy.girl.pp.ua";
      };
    };
  };
  config = lib.mkIf cfg.services.ntfy.enable {
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${cfg.services.ntfy.domain}";
        upstream-base-url = "https://ntfy.sh";
        listen-http = "127.0.0.1:${toString cfg.services.ntfy.port}";
        behind-proxy = true;
        # enable-signup = true;
        # enable-login = true;
        enable-reservations = true;
      };
    };

    services.caddy.virtualHosts = {
      ${cfg.services.ntfy.domain} = {
        extraConfig = ''
          reverse_proxy localhost:${toString cfg.services.ntfy.port}
        '';
      };
    };
  };
}