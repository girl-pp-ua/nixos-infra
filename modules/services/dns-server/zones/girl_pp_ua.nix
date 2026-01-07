# shit's legacy
{ config, dns, ... }:
with dns.lib.combinators;
let
  inherit (config.polaris) hosts;

  name = "girl.pp.ua";
  serial = 2026010400; # YYYYMMDDNN

  /**
    Creates a CNAME record
  */
  mkCname = target: { CNAME = [ target ]; };

  /**
    Shorthand for { subdomains = ...; }
  */
  withSubdomains = subdomains: { inherit subdomains; };

  /**
    Creates A + AAAA records for a host
  */
  mkHost = hostAddr: with hostAddr; host ipv4 ipv6;

  /**
    Creates A + AAAA records and ipv4.@ and ipv6.@ subdomains
  */
  mkDualstackHost =
    dsHost:
    with dsHost;
    (
      host ipv4 ipv6
      // withSubdomains {
        ipv4 = host ipv4 null;
        ipv6 = host null ipv6;
      }
    );

  /**
    IPv4/IPv6 addresses of physical hosts
  */
in
{
  polaris.services.dns-server.zones.${name} = {
    TTL = 1800; # 30 minutes

    SOA = {
      nameServer = "ns1.${name}.";
      adminEmail = "prasol258@gmail.com";
      inherit serial;
    };

    NS = [
      "ns1.${name}."
      "ns2.${name}."
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
      # hosts (public):
      oci1 = mkDualstackHost hosts.oci1.public;
      oci2 = mkDualstackHost hosts.oci2.public;
      # oci-loadbalancer = mkDualstackHost hosts.oci-loadbalancer.public;
      # cocoa = mkDualstackHost hosts.cocoa;

      # nameservers:
      ns1 = mkHost hosts.oci1.public;
      ns2 = mkHost hosts.oci2.public;

      # services:
      # --- oci1 ---
      files = mkCname "oci1.${name}.";
      webdav =
        mkCname "oci1.${name}."
        // withSubdomains {
          # (workaround: Dolphin trying to connect over IPv6 on IPv4-only network)
          legacy = mkCname "ipv4.oci1.${name}.";
        };
      sso = mkCname "oci1.${name}.";
      status = mkCname "oci1.${name}.";
      authtest = mkCname "oci1.${name}."; # testing
      # --- oci2 ---
      redlib = mkCname "oci2.${name}.";
      ntfy = mkCname "oci2.${name}.";
      cloud = mkCname "oci2.${name}."; # (proxy -> dell-sv)
      paperless = mkCname "oci2.${name}."; # (proxy -> dell-sv)
      photos = mkCname "oci2.${name}."; # (proxy -> dell-sv)

      # cdn:
      files-cdn =
        mkCname "t.sni.global.fastly.net."
        // withSubdomains {
          _acme-challenge = mkCname "9ju9qpopwm9fbqid5n.fastly-validations.com.";
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
      _mythic-beasts-challenge.TXT = [ "deLHF0cTTKZyR/l41XoMJcDVKGwpOXj+gpyO6o1sLdQ" ];

      # internal services (tailscale/vpn)
      # XXX: this is deprecated and about to be removed
      intranet.subdomains = {
        dell-sv = mkDualstackHost hosts.dell-sv.internal;
      };
    };
  };
}
