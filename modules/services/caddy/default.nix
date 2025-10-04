{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config) cfg;
in
{
  imports = [
    ./endpoints/file-server.nix
    ./endpoints/healthcheck.nix
    ./endpoints/proxies.nix
    ./endpoints/webdav.nix
    ./endpoints/authtest.nix
  ];
  options = {
    cfg.services.caddy.enable = lib.mkEnableOption "caddy";
  };
  config = lib.mkIf cfg.services.caddy.enable {
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/mholt/caddy-webdav@v0.0.0-20250609161527-33ba3cd2088c"
        ];
        hash = "sha256-+JFcLHn10sPTTWnf7jQQ+AXBzA5dyb586Ez0kIhNySw=";
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
        (norobot) {
          header {
            X-Robots-Tag "noindex, nofollow"
          }
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

    # force nginx off
    services.nginx.enable = lib.mkForce false;
  };
}
