{ config, lib, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.caddy.enable = lib.mkEnableOption "caddy" // {
      default = true;
    };
  };
  config = lib.mkIf cfg.services.caddy.enable {
    services.caddy = {
      enable = true;
      enableReload = true;
      adapter = "caddyfile";
      email = "prasol258@gmail.com";
      globalConfig = ''
        grace_period 30s
        skip_install_trust
        renew_interval 30m
      '';
      extraConfig = ''
        (cors) {
          @origin{args[0]} header Origin {args[0]}
          header @origin{args[0]} Access-Control-Allow-Origin "{args[0]}"
          header @origin{args[0]} Vary Origin
        }
        (encode) {
          encode zstd gzip
        }
      '';
    };
    networking.firewall = {
      allowedTCPPorts = [ 80 443 ];
      allowedUDPPorts = [ 443 ];
    };
  };
}