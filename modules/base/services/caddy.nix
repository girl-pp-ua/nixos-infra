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
          "github.com/caddy-dns/acmedns@v0.4.1"
        ];
        hash = "sha256-+cfmKSbh3pJQW8ikAckA0RTbXuUsSPPiIQkt1Ev65ZQ=";
      };
      enableReload = true;
      adapter = "caddyfile";
      email = "prasol258@gmail.com";
      globalConfig = ''
        grace_period 30s
        skip_install_trust
        renew_interval 30m
        order webdav before file_server
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
      allowedTCPPorts = [
        80
        443
      ];
      allowedUDPPorts = [ 443 ];
    };
  };
}
