{ dns }:
with dns.lib.combinators;
let
  zone = "girl.pp.ua.";
  serial = 2024112801;

  /**
    Creates A + AAAA records and ipv4.@ and ipv6.@ subdomains
  */
  mkDualstackHost = ipv4: ipv6:
    host ipv4 ipv6
    // {
      subdomains = {
        ipv4 = host ipv4 null;
        ipv6 = host null ipv6;
      };
    };

  /**
    Creates a CNAME record
  */
  mkCname = target: { CNAME = [ target ]; };

  /**
    IPv4/IPv6 addresses of physical hosts
  */
  hosts = {
    # oci1: Oracle Cloud Infrastructure (Frankfurt) - VM.Standard.E2.1.Micro
    oci1 = {
      ipv4 = "132.226.204.218";
      ipv6 = "2603:c020:800c:9c7f:0:fe:fe:2";
    };

    # oci2: Oracle Cloud Infrastructure (Frankfurt) - VM.Standard.E2.1.Micro
    oci2 = {
      ipv4 = "144.24.178.67";
      ipv6 = "2603:c020:800c:9c7f:0:ba:be:2";
    };
  };
in
{
  TTL = 1800; # 30 minutes

  SOA = {
    nameServer = "ns2.${zone}";
    adminEmail = "prasol258@gmail.com";
    inherit serial;
  };

  NS = [
    "ns1.${zone}"
    "ns2.${zone}"
  ];

  # TODO set up ALIAS to beeg-pp-infra.netlify.app instead
  A = [
    # apex-loadbalancer.netlify.com
    "75.2.60.5"
  ];
  AAAA = [
    # from `dig AAAA beeg.pp.ua`; not guaranteed to be stable!
    "2a05:d014:58f:6200::65"
    "2a05:d014:58f:6201::65"
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
    "v=spf1 -all"
    "oci-domain-verification=NpKOKeYeCal32nE30tzSHLI9RXw41sPKLASaWVs0JXMpD"
  ];

  subdomains = {
    # hosts:
    oci1 = with hosts; mkDualstackHost oci1.ipv4 oci1.ipv6;
    oci2 = with hosts; mkDualstackHost oci2.ipv4 oci2.ipv6;

    # nameservers:
    ns1 = with hosts; host oci1.ipv4 oci1.ipv6;
    ns2 = with hosts; host oci2.ipv4 oci2.ipv6;

    # services:
    files  = mkCname "oci1.${zone}";
    sso    = mkCname "oci1.${zone}";
    redlib = mkCname "oci2.${zone}";
    ntfy   = mkCname "oci2.${zone}";

    # cdn:
    files-cdn = {
      CNAME = [ "t.sni.global.fastly.net." ];
      subdomains._acme-challenge = {
        CNAME = [ "9ju9qpopwm9fbqid5n.fastly-validations.com." ];
      };
    };

    # misc.:
    infra = mkCname "beeg-pp-infra.netlify.app.";

    # legacy services:
    services.subdomains = {
      uptime = mkCname "oci1.${zone}";
    };

    # TXT records:
    _atproto.TXT = [ "did=did:plc:wvftnj7awmh4gwf3pt5mlvwq" ];
  };
}