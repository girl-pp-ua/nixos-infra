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
    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 9180;
    };
    # (only listen on loopback and this host's tailnet addresses)
    internalListenAddresses = lib.mkOption {
      type = with lib.types; listOf str;
      readOnly = true;
      default = with config.polaris.hosts.${config.networking.hostName}.internal; [
        "127.0.0.1"
        "::1"
        ipv4
        ipv6
      ];
    };

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
              "github.com/mholt/caddy-webdav@v0.0.0-20260127042217-fa2f366b0d75"
              # "github.com/corazawaf/coraza-caddy/v2@v2.1.0"
            ];
            hash = "sha256-+Nm1wgpU06cpG40Or1WqK5gjbjHe7cNyTIiXleq9Bs8=";
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
        metrics {
          per_host
        }
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
    services.caddy.virtualHosts."http://:${toString cfg.metricsPort}".extraConfig = "metrics";
    polaris.services.monitoring.exports.caddy.port = cfg.metricsPort;

    networking.firewall = {
      allowedTCPPorts = [
        80
        443
      ];
      allowedUDPPorts = [ 443 ];
    };

    # caddy may start before tailscale brings up its addresses
    boot.kernel.sysctl = {
      "net.ipv4.ip_nonlocal_bind" = 1;
      "net.ipv6.ip_nonlocal_bind" = 1;
    };

    # force nginx off
    services.nginx.enable = lib.mkForce false;
  };
}
