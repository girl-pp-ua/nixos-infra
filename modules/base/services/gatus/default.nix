{ config, lib, ... }:
let
  inherit (config) cfg;

  mkGroups =
    groups:
    lib.concatLists (
      lib.map (group: lib.map (item: item // { group = group.name; }) group.endpoints) groups
    );

  # test that host can be pinged
  mkPing = name: host: {
    inherit name;
    url = "icmp://${host}";
    conditions = [
      "[CONNECTED] == true"
    ];
  };
  # test that nameserver can resolve itself
  mkNs = name: host: ip: {
    inherit name;
    url = ip;
    dns = {
      query-name = host;
      query-type = "A";
    };
    conditions = [
      "[BODY] == ${ip}"
      "[DNS_RCODE] == NOERROR"
    ];
  };
in
{
  imports = [
    ./multi-instance.nix
  ];
  options = {
    cfg.services.gatus = {
      enable = lib.mkEnableOption "gatus";
    };
  };
  config = lib.mkIf cfg.services.gatus.enable {
    services.gatus.instances = {
      girl-pp-ua = {
        port = 16040;
        settings = {
          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/data-girl-pp-ua.db";
            maximum-number-of-results = 1000;
            maximum-number-of-events = 500;
          };
          endpoints = mkGroups [
            {
              name = "hosts";
              endpoints = [
                (mkPing "oci1" "oci1.girl.pp.ua")
                (mkPing "oci2" "oci2.girl.pp.ua")
                (mkPing "cocoa" "cocoa.girl.pp.ua")
                (mkPing "dell-sv" "dell-sv.intranet.girl.pp.ua")
              ];
            }
            {
              name = "nameservers";
              endpoints = [
                (mkNs "ns1" "ns1.girl.pp.ua" "132.226.204.218")
                (mkNs "ns2" "ns2.girl.pp.ua" "144.24.178.67")
              ];
            }
            {
              name = "services";
              endpoints = [
                {
                  name = "nextcloud";
                  url = "https://cloud.girl.pp.ua/status.php";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY].productname == Nextcloud"
                    "[BODY].installed == true"
                    "[BODY].maintenance == false"
                    "[BODY].needsDbUpgrade == false"
                  ];
                }
                {
                  name = "redlib";
                  url = "https://redlib.girl.pp.ua/r/test/comments/1l8wdxa";
                  interval = "6h";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*xiphoihaej5io8oSheiXie4gu9ixahs0ian5iemo9ohhieBaom4Ideiquoh7ai8e*)"
                  ];
                }
              ];
            }
          ];
        };
      };
    };

    services.caddy.virtualHosts."status.girl.pp.ua" = {
      extraConfig = ''
        import encode
        reverse_proxy http://localhost:${toString config.services.gatus.instances.girl-pp-ua.port}
      '';
    };
  };
}
