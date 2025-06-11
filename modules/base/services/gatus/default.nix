{ config, lib, ... }:
let
  inherit (config) cfg;

  mkGroups =
    groups:
    lib.concatLists (
      lib.mapAttrsToList (group: items: lib.map (item: item // { inherit group; }) items) groups
    );
  mkEndpoints = items: lib.mapAttrsToList (name: item: item // { inherit name; }) items;

  # test that host can be pinged
  mkPing = host: {
    url = "icmp://${host}";
    conditions = [
      "[CONNECTED] == true"
    ];
  };
  # test that nameserver can resolve itself
  mkDns = host: ip: {
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
  mkUrl = url: conditions: {
    inherit url conditions;
  };

  mergeAll = common: lib.map (value: common // value);
in
{
  imports = [
    ./gatus-multi-instance.nix
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
          ui = {
            title = "🏳️‍⚧️ girl.pp.ua Status";
            # TODO custom-css
          };
          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/data-girl-pp-ua.db";
            maximum-number-of-results = 1440;
            maximum-number-of-events = 300;
          };
          alerting.ntfy = {
            topic = "gatus-girl-pp-ua";
            url = "https://${cfg.services.ntfy.domain}";
            click = "https://status.girl.pp.ua/";
          };
          endpoints =
            let
              withAlert = {
                alerts = [
                  { type = "ntfy"; }
                ];
              };
            in
            mergeAll withAlert (mkGroups {
              hosts = mkEndpoints {
                oci1 = mkPing "oci1.girl.pp.ua";
                oci2 = mkPing "oci2.girl.pp.ua";
                cocoa = mkPing "cocoa.girl.pp.ua";
                dell-sv = mkPing "dell-sv.intranet.girl.pp.ua";
              };
              nameservers = mkEndpoints {
                ns1 = mkDns "ns1.girl.pp.ua" "132.226.204.218";
                ns2 = mkDns "ns2.girl.pp.ua" "144.24.178.67";
              };
              services = mkEndpoints {
                nextcloud = mkUrl "https://cloud.girl.pp.ua/status.php" [
                  "[STATUS] == 200"
                  "[BODY].productname == Nextcloud"
                  "[BODY].installed == true"
                  "[BODY].maintenance == false"
                  "[BODY].needsDbUpgrade == false"
                ];
                nextcloud-whiteboard-server = mkUrl "https://cloud.girl.pp.ua/whiteboard/" [
                  "[STATUS] == 200"
                  "[BODY] == pat(*Excalidraw collaboration server is up :)*)"
                ];
                redlib = mkUrl "https://redlib.girl.pp.ua/r/test/comments/1l8wdxa" [
                  "[STATUS] == 200"
                  "[BODY] == pat(*xiphoihaej5io8oSheiXie4gu9ixahs0ian5iemo9ohhieBaom4Ideiquoh7ai8e*)"
                ];
                kanidm = mkUrl "https://sso.girl.pp.ua/status" [
                  "[STATUS] == 200"
                  "[BODY] == true"
                ];
                ntfy = mkUrl "https://ntfy.girl.pp.ua/v1/health" [
                  "[STATUS] == 200"
                  "[BODY].healthy == true"
                ];
              };
            });
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
