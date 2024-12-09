{ config, pkgs, lib, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.caddy.enable = lib.mkEnableOption "caddy" // {
      default = true;
    };
  };
  config = lib.mkIf cfg.services.caddy.enable {
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/mholt/caddy-webdav@v0.0.0-20241008162340-42168ba04c9d"
          "github.com/caddyserver/replace-response@v0.0.0-20240710174758-f92bc7d0c29d"
        ];
        hash = "sha256-uhf4lBSCcMuWYQP6q3ZrjFq5JmyXEfyXUTBJoqY10tg=";
      };
      enableReload = true;
      adapter = "caddyfile";
      email = "prasol258@gmail.com";
      globalConfig = ''
        grace_period 30s
        skip_install_trust
        renew_interval 30m
        order replace after encode
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