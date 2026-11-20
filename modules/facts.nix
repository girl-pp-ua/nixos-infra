{ config, lib, ... }:
{
  options.polaris.hosts = lib.mkOption {
    type = with lib.types; attrsOf attrs;
    default = { };
  };

  config.polaris.hosts = import ../data/hosts.nix;

  options.polaris.trustedNetworks = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ ];
  };

  config.polaris.trustedNetworks = [
    # loopback
    "127.0.0.0/8"
    "::1"
    # tailscale
    "fd7a:115c:a1e0::/48"
    "100.64.0.0/16"
  ]
  # internal ips of our hosts
  ++ (lib.pipe config.polaris.hosts [
    (lib.mapAttrsToList (
      _: host: [
        host.internal.ipv4 or null
        host.internal.ipv6 or null
      ]
    ))
    lib.concatLists
    (lib.filter (ip: ip != null))
  ]);

}
