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
      serial = 2026040801; # YYYYMMDDNN
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
      "$argon2id$v=19$m=512,t=256,p=1$9qUkhB9I4tK2n5v00pLnvg$yAO8W0NDNMJY/CwJPieSTfWUh8OqCSEFY0xMrunlD6U" # keyoxide
    ];

    subdomains = {
      oci1 = with hosts.oci1.public; host ipv4 ipv6;
      oci2 = with hosts.oci2.public; host ipv4 ipv6;
      astra = with hosts.astra.public; host ipv4 ipv6;

      ns1 = with hosts.oci1.public; host ipv4 ipv6;
      ns2 = with hosts.oci2.public; host ipv4 ipv6;

      dell-sv-proxy.CNAME = [ "astra" ]; # -> reverse proxy

      status.CNAME = [ "oci1" ];
      photos.CNAME = [ "dell-sv-proxy" ];
      paperless.CNAME = [ "dell-sv-proxy" ];
      cloud.CNAME = [ "dell-sv-proxy" ];
      git.CNAME = [ "dell-sv-proxy" ];
      # ntfy.CNAME = [ "oci2" ];
      # docs.CNAME = [ "dell-sv-proxy" ];

      _atproto.TXT = [ "did=did:plc:wvftnj7awmh4gwf3pt5mlvwq" ];
    };
  };
}
