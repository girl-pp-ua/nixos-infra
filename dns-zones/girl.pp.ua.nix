{ dns }:
with dns.lib.combinators;
let
  zone = "girl.pp.ua.";

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
in
{
  TTL = 1800; # 30 minutes

  SOA = {
    nameServer = "ns2.${zone}";
    adminEmail = "prasol258@gmail.com";
    serial = 2024112200;
  };

  NS = [
    "ns1.${zone}"
    "ns2.${zone}"
  ];

  # TODO set up ALIAS to beeg-pp-infra.netlify.app instead
  # apex-loadbalancer.netlify.com
  A = [
    "75.2.60.5"
  ];

  # TXT records
  TXT = [ "oci-domain-verification=NpKOKeYeCal32nE30tzSHLI9RXw41sPKLASaWVs0JXMpD" ];
  subdomains._atproto.TXT = [ "did=did:plc:wvftnj7awmh4gwf3pt5mlvwq" ];

  subdomains = {
    # oci1: Oracle Cloud Infrastructure (Frankfurt) - VM.Standard.E2.1.Micro
    oci1 = mkDualstackHost
      "132.226.204.218"
      "2603:c020:800c:9c7f:0:fe:fe:2";

    # oci2: Oracle Cloud Infrastructure (Frankfurt) - VM.Standard.E2.1.Micro
    oci2 = mkDualstackHost
      "144.24.178.67"
      "2603:c020:800c:9c7f:0:ba:be:2";

    # nameservers:
    ns1 = mkCname "oci1.${zone}";
    ns2 = mkCname "oci2.${zone}";

    # services:
    redlib = mkCname "oci2.${zone}";
    ntfy   = mkCname "oci2.${zone}";

    # legacy services:
    services.subdomains = {
      uptime = mkCname "oci1.${zone}";
    };
  };
}