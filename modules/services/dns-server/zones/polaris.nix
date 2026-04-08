{ config, dns, ... }:
with dns.lib.combinators;
let
  inherit (config.polaris) hosts;
  name = "polaris";
in
{
  polaris.services.dns-server.zones.${name} = {
    TTL = 1800; # 30 minutes
    SOA = {
      nameServer = "localhost";
      adminEmail = "nobody@localhost";
      serial = 2026040801; # YYYYMMDDNN
    };

    subdomains = {
      oci1 = with hosts.oci1.internal; host ipv4 ipv6;
      oci2 = with hosts.oci2.internal; host ipv4 ipv6;
      dell-sv = with hosts.dell-sv.internal; host ipv4 ipv6;
      astra = with hosts.astra.internal; host ipv4 ipv6;

      garage.CNAME = [ "oci1" ];
      nextcloud.CNAME = [ "dell-sv" ];
      paperless.CNAME = [ "dell-sv" ];
      immich.CNAME = [ "dell-sv" ];
      forgejo.CNAME = [ "dell-sv" ];
    };
  };
}
