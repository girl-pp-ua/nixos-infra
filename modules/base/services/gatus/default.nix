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
