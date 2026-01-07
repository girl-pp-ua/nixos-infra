{ config, lib, ... }:

{
  options.polaris.hosts = lib.mkOption {
    type = with lib.types; attrsOf attrs;
    default = { };
  };

  config.polaris.hosts = {
    # oci1: Oracle Cloud Infrastructure (Frankfurt) - VM.Standard.E2.1.Micro
    oci1 = {
      public = {
        fqdn = "oci1.lunya.cc";
        ipv4 = "132.226.204.218";
        ipv6 = "2603:c020:800c:9c7f:0:fe:fe:2";
      };
      internal = {
        fqdn = "oci1.polaris";
        ipv4 = "100.64.0.101";
        ipv6 = "fd7a:115c:a1e0::2a01:371";
      };
    };

    # oci2: Oracle Cloud Infrastructure (Frankfurt) - VM.Standard.E2.1.Micro
    oci2 = {
      public = {
        fqdn = "oci2.lunya.cc";
        ipv4 = "144.24.178.67";
        ipv6 = "2603:c020:800c:9c7f:0:ba:be:2";
      };
      internal = {
        fqdn = "oci2.polaris";
        ipv4 = "100.64.0.102";
        ipv6 = "fd7a:115c:a1e0::2501:5a59";
      };
    };

    # oci-loadbalancer: Oracle Cloud Infrastructure - test-loadbalancer
    # oci-loadbalancer = {
    #   public = {
    #     ipv4 = "130.61.214.159";
    #     ipv6 = "2603:c020:800c:9c7f:3906:822b:23d9:899c";
    #   };
    # };

    # (intranet) dell-sv; tailscale ips
    dell-sv = {
      internal = {
        fqdn = "dell-sv.polaris";
        ipv4 = "100.64.0.2";
        ipv6 = "fd7a:115c:a1e0::2901:2214";
      };
    };
  };

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
