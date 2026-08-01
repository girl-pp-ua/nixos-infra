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
    "127.0.0.1"
    "127.0.0.0/8"
    "::1"
    # local ranges
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    # local ranges ipv6
    "fc00::/7"
    # tailscale
    "fd7a:115c:a1e0::/48"
    "100.64.0.0/16"
    # oci primary-vcn
    "2603:c020:800c:9c00::/56"
  ]
  # public, tailscale ips are considered trusted
  ++ (lib.pipe config.polaris.hosts [
    (lib.mapAttrsToList (
      _: host: [
        host.public.ipv4 or null
        host.public.ipv6 or null
        host.internal.ipv4 or null
        host.internal.ipv6 or null
      ]
    ))
    lib.concatLists
    (lib.filter (ip: ip != null))
  ]);

}
