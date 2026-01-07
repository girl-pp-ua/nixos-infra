{ config, dns, ... }:
with dns.lib.combinators;
let
  inherit (config.polaris) hosts;
  name = "lunya.cc";
in
{
  polaris.services.dns-server.zones.${name} = {
    TTL = 1800; # 30 minutes
    SOA = {
      nameServer = "ns1.${name}.";
      adminEmail = "hostmaster@${name}";
      serial = 2026010400; # YYYYMMDDNN
    };

    NS = [
      "ns1"
      "ns2"
    ];

    DMARC = [
      {
        p = "reject";
        sp = "reject";
        adkim = "strict";
        aspf = "strict";
      }
    ];
    TXT = [
      (spf.strict [ ])
    ];

    subdomains = {
      oci1 = with hosts.oci1.public; host ipv4 ipv6;
      oci2 = with hosts.oci2.public; host ipv4 ipv6;

      ns1 = with hosts.oci1.public; host ipv4 ipv6;
      ns2 = with hosts.oci2.public; host ipv4 ipv6;

      dell-sv-proxy.CNAME = [ "oci2" ]; # -> reverse proxy

      status.CNAME = [ "oci1" ];
      ntfy.CNAME = [ "oci2" ];

      reddit.CNAME = [ "oci2" ];

      cloud.CNAME = [ "dell-sv-proxy" ];
      photos.CNAME = [ "dell-sv-proxy" ];
      docs.CNAME = [ "dell-sv-proxy" ];
    };
  };
}
