{ ... }:
let
  zone = "nix-infra.";
in
{
  TTL = 1800; # 30 minutes
  SOA = {
    nameServer = "localhost";
    adminEmail = "nobody@localhost";
    serial = 2025092201; # YYYYMMDDNN
  };

  subdomains = {
    nextcloud.CNAME = [ "dell-sv.ts.${zone}" ];
    paperless.CNAME = [ "dell-sv.ts.${zone}" ];

    ts.subdomains = {
      oci1 = {
        AAAA = [ "fd7a:115c:a1e0::2a01:371" ];
        A = [ "100.64.0.101" ];
      };
      oci2 = {
        AAAA = [ "fd7a:115c:a1e0::2501:5a59" ];
        A = [ "100.64.0.102" ];
      };
      dell-sv = {
        AAAA = [ "fd7a:115c:a1e0::2901:2214" ];
        A = [ "100.64.0.2" ];
      };
    };
  };
}
