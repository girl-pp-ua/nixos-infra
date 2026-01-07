{
  config,
  lib,
  secrets,
  ...
}:
let
  cfg = config.polaris.services.gatus;
  cfg-svc = config.polaris.services;

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
  mkUrl = url: {
    inherit url;
  };
  mkUrl' = url: conditions: {
    inherit url conditions;
  };

  withHidden = {
    ui = {
      hide-hostname = true;
      hide-url = true;
      # hide-port = true;
    };
  };
  withIsConnected = {
    conditions = [
      "[CONNECTED] == true"
    ];
  };
  withAlertsNtfy = {
    alerts = [
      { type = "ntfy"; }
    ];
  };

  mergeAll = common: lib.map (value: common // value);

  # gatus' = pkgs.gatus.overrideAttrs (oldAttrs: {
  #   patches = (oldAttrs.patches or [ ]) ++ [
  #     (pkgs.fetchpatch {
  #       url = "https://patch-diff.githubusercontent.com/raw/TwiN/gatus/pull/1344.patch";
  #       hash = "sha256-HCbfz/TbvjP/TJyo6lnJNhV9fSXx4TG9c9d4T3dUy80=";
  #     })
  #   ];
  # });
in
{
  imports = [
    ./gatus-multi-instance.nix
  ];

  options = {
    polaris.services.gatus = {
      enable = lib.mkEnableOption "gatus";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gatus = {
      # package = gatus';
      instances = {
        girl-pp-ua = {
          port = 16040;
          settings = {
            ui = {
              title = "🏳️‍⚧️ Status";
              # default-sort-by = "group";
              # TODO custom-css
            };
            storage = {
              type = "sqlite";
              path = "/var/lib/gatus/data-girl-pp-ua.db";
              maximum-number-of-results = 1440;
              maximum-number-of-events = 300;
            };
            alerting.ntfy = {
              topic = secrets.ntfy-topics.gatus-girl-pp-ua;
              url = "https://${cfg-svc.ntfy.domain}";
              click = "https://status.girl.pp.ua/";
            };
            endpoints = mergeAll withAlertsNtfy (mkGroups {
              hosts = mkEndpoints {
                oci1 = mkPing "oci1.polaris";
                oci2 = mkPing "oci2.polaris";
                dell-sv = mkPing "dell-sv.polaris";
              };
              nameservers = mkEndpoints {
                ns1 = mkDns "ns1.girl.pp.ua" "132.226.204.218";
                ns2 = mkDns "ns2.girl.pp.ua" "144.24.178.67";
              };
              services = mkEndpoints {
                kanidm = mkUrl' "https://${cfg-svc.kanidm.domain}/status" [
                  "[STATUS] == 200"
                  "[BODY] == true"
                ];
                nextcloud = mkUrl' "https://${cfg-svc.nextcloud.domain}/status.php" [
                  "[STATUS] == 200"
                  "[BODY].productname == Nextcloud"
                  "[BODY].installed == true"
                  "[BODY].maintenance == false"
                  "[BODY].needsDbUpgrade == false"
                ];
                ntfy = mkUrl' "https://${cfg-svc.ntfy.domain}/v1/health" [
                  "[STATUS] == 200"
                  "[BODY].healthy == true"
                ];
                redlib = mkUrl "https://${cfg-svc.redlib.domain}/r/test/comments/1l8wdxa" // {
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*xiphoihaej5io8oSheiXie4gu9ixahs0ian5iemo9ohhieBaom4Ideiquoh7ai8e*)"
                  ];
                  interval = "2h"; # reddit please don't kill me
                };
                garage-s3 = mkUrl' "http://${cfg-svc.garage.intraDomain}:3900/" [
                  # idk what else to check fo here
                  "[STATUS] == 403"
                  "[BODY] == pat(*<Region>garage</Region>*)"
                ];
                garage-web-devlootbox = mkUrl' "https://media-cdn.devlootbox.com/" [
                  "[STATUS] == 404"
                  "[BODY] == pat(*NoSuchKey*)"
                ];
                paperless = mkUrl' "https://${cfg-svc.paperless.domain}/" [
                  "[STATUS] == 200"
                ];
                immich = mkUrl' "https://${cfg-svc.immich.domain}/api/server/ping" [
                  "[STATUS] == 200"
                  "[BODY].res == pong"
                ];
              };
              nextcloud-apps = mkEndpoints {
                nextcloud-whiteboard = mkUrl' "https://${cfg-svc.nextcloud.domain}/whiteboard/" [
                  "[STATUS] == 200"
                  "[BODY] == pat(*Nextcloud Whiteboard Collaboration Server*)"
                ];
                nextcloud-collabora = mkUrl' "https://${cfg-svc.nextcloud.domain}/hosting/capabilities" [
                  "[STATUS] == 200"
                  "[BODY].productName == Collabora Online Development Edition"
                ];
                nextcloud-push-notify = mkUrl' "https://${cfg-svc.nextcloud.domain}/push/test/cookie" [
                  "[STATUS] == 200"
                ];
              };
            });
          };
        };

        nyanbinary-rs = {
          port = 16041;
          settings = {
            storage = {
              type = "sqlite";
              path = "/var/lib/gatus/data-nyanbinary-rs.db";
              maximum-number-of-results = 1440;
              maximum-number-of-events = 300;
            };
            alerting.ntfy = {
              topic = secrets.ntfy-topics.gatus-nyanbinary-rs;
              url = "https://${cfg-svc.ntfy.domain}";
              click = "https://status.nyanbinary.rs/";
            };
            endpoints = mergeAll withAlertsNtfy (mkGroups {
              hosts = mkEndpoints {
                ex44 = mkPing secrets.nyanbinary.upstream.ipv4 // withHidden;
              };

              services = mkEndpoints {
                web = mkUrl' "https://nyanbinary.rs/" [
                  "[STATUS] == 200"
                ];
                matrix-continuwuity = mkUrl' "https://matrix.nyanbinary.rs/_matrix/federation/v1/version" [
                  "[STATUS] == 200"
                  "[BODY].server.name == continuwuity"
                ];
              };

              services-game-servers =
                mergeAll (withIsConnected // withHidden // { interval = "5m"; })
                  (mkEndpoints {
                    minecraft-prominence = mkUrl "tcp://${secrets.nyanbinary.upstream.ipv4}:25565";
                    minecraft-vanilla = mkUrl "tcp://${secrets.nyanbinary.upstream.ipv4}:25565";
                    vintage-story = mkUrl "tcp://${secrets.nyanbinary.upstream.ipv4}:42420";
                  });
            });
          };
        };
      };

    };

    services.caddy.virtualHosts =
      let
        mkVirtualHost = name: {
          extraConfig = ''
            import encode
            import norobot
            reverse_proxy http://localhost:${toString config.services.gatus.instances.${name}.port}
          '';
        };
      in
      {
        "status.girl.pp.ua" = mkVirtualHost "girl-pp-ua";
        "status.nyanbinary.rs" = mkVirtualHost "nyanbinary-rs";
      };
  };
}
