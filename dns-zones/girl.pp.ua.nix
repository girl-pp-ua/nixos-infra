{ dns }:
with dns.lib.combinators;
let
  zone = "girl.pp.ua.";
  serial = 2025060401;

  /**
    Creates A + AAAA records and ipv4.@ and ipv6.@ subdomains
  */
  mkDualstackHost =
    ipv4: ipv6:
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

    # oci-loadbalancer: Oracle Cloud Infrastructure - test-loadbalancer
    oci-loadbalancer = {
      ipv4 = "130.61.214.159";
      ipv6 = "2603:c020:800c:9c7f:3906:822b:23d9:899c";
    };

    # (intranet) dell-sv
    dell-sv = {
      ipv4 = "100.64.0.2";
      ipv6 = "fd7a:115c:a1e0::2901:2214";
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
    oci-loadbalancer = with hosts; mkDualstackHost oci-loadbalancer.ipv4 oci-loadbalancer.ipv6;

    # nameservers:
    ns1 = with hosts; host oci1.ipv4 oci1.ipv6;
    ns2 = with hosts; host oci2.ipv4 oci2.ipv6;

    # services:
    files = mkCname "oci1.${zone}";
    webdav = mkCname "oci1.${zone}" // {
      # (workaround: Dolphin trying to connect over IPv6 on IPv4-only hosts)
      subdomains.legacy = mkCname "ipv4.oci1.${zone}";
    };
    sso = mkCname "oci1.${zone}";
    redlib = mkCname "oci2.${zone}";
    ntfy = mkCname "oci2.${zone}";
    uptime = mkCname "oci1.${zone}";
    status = mkCname "oci1.${zone}";

    # testing:
    oauth2 = mkCname "oci1.${zone}";
    fwauthtest1 = mkCname "oci1.${zone}";

    # cdn:
    files-cdn = {
      CNAME = [ "t.sni.global.fastly.net." ];
      subdomains._acme-challenge = {
        CNAME = [ "9ju9qpopwm9fbqid5n.fastly-validations.com." ];
      };
    };

    # misc.:
    infra.NS = [
      "dns1.p09.nsone.net."
      "dns2.p09.nsone.net."
      "dns3.p09.nsone.net."
      "dns4.p09.nsone.net."
    ];

    # TXT records:
    _atproto.TXT = [ "did=did:plc:wvftnj7awmh4gwf3pt5mlvwq" ];
    _discord.TXT = [ "dh=ed7fe6618b265997be79e5e393a215136aafaa28" ];

    # internal services (tailscale/vpn)
    intranet.subdomains = {
      dell-sv = mkDualstackHost hosts.dell-sv.ipv4 hosts.dell-sv.ipv6;
      nextcloud = mkCname "dell-sv.intranet.${zone}";
    };
  };
}
