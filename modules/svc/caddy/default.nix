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
          "github.com/mholt/caddy-webdav@v0.0.0-20250805175825-7a5c90d8bf90"
        ];
        hash = "sha256-DHkHbwhTnaK00G38czb4XZ9g9Ttz9Y1Wb3gCCAWZYDI=";
      };
      enableReload = true;
      adapter = "caddyfile";
      email = "prasol258@gmail.com";
      globalConfig = ''
        grace_period 30s
        skip_install_trust
        renew_interval 30m
        order webdav before file_server
        servers {
          trusted_proxies static private_ranges ${
            # TODO dont hardcode this
            lib.concatStringsSep " " [
              # tailscale
              "fd7a:115c:a1e0::/48"
              "100.64.0.0/16"
              # oci primary-vcn
              "2603:c020:800c:9c00::/56"
              "132.226.204.218" # oci1
              "144.24.178.67" # oci2
            ]
          }
          trusted_proxies_strict
          enable_full_duplex
        }
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
        (nextcloud_sec) {
          header {
            X-Content-Type-Options nosniff
            X-Robots-Tag noindex,nofollow
            X-Frame-Options sameorigin
            X-Permitted-Cross-Domain-Policies none
            Referrer-Policy no-referrer
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
    
    # due to notify_push stuff, we must trust ourselves and we can only guarantee that 
  };
}
