{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.nix-infra.svc.caddy;
in
{
  imports = [
    ./endpoints/file-server.nix
    ./endpoints/healthcheck.nix
    ./endpoints/proxies.nix
    ./endpoints/webdav.nix
    ./endpoints/authtest.nix
  ];

  options.nix-infra.svc.caddy = {
    enable = lib.mkEnableOption "caddy";
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/mholt/caddy-webdav@v0.0.0-20250609161527-33ba3cd2088c"
        ];
        hash = "sha256-Q8WZMGUgYwDQJI/ZXRET5jRrsxxGcF4/2sbixgw0Rk4=";
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
