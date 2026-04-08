{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.polaris.services.caddy;
in
{
  imports = [
    ./endpoints/file-server.nix
    ./endpoints/webdav.nix
    ./endpoints/authtest.nix
    ./endpoints/proxies.nix
  ];

  options.polaris.services.caddy = {
    enable = lib.mkEnableOption "caddy";

    plugins = {
      enable = lib.mkEnableOption "plugins" // {
        default = cfg.plugins.webdav;
      };
      webdav = lib.mkEnableOption "caddy webdav plugin";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      package =
        if cfg.plugins.enable then
          pkgs.caddy.withPlugins {
            plugins = [
              "github.com/mholt/caddy-webdav@v0.0.0-20250805175825-7a5c90d8bf90"
              # "github.com/corazawaf/coraza-caddy/v2@v2.1.0"
            ];
            hash = "sha256-n1Bf/wB838qlEqCjPXGMTqEN3lT3qt09G3Zhc60s/Iw=";
          }
        else
          pkgs.caddy;
      enableReload = true;
      adapter = "caddyfile";
      email = "prasol258@gmail.com";
      globalConfig = ''
        grace_period 30s
        skip_install_trust
        renew_interval 30m
        ${lib.optionalString cfg.plugins.webdav "order webdav before file_server"}
        servers {
          trusted_proxies static private_ranges ${lib.concatStringsSep " " config.polaris.trustedNetworks}
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
