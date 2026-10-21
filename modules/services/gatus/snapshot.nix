{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.polaris.services.gatus.snapshot;
  inherit (config.networking) hostName;
  source = config.polaris.hosts.${cfg.source}.internal;
  instances = inputs.self.nixosConfigurations.${cfg.source}.config.services.gatus.instances;

  nodeModules = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./snapshot;
    inherit (pkgs) nodejs;
  };
in
{
  options.polaris.services.gatus.snapshot = {
    source = lib.mkOption {
      type = lib.types.str;
      default = "oci1";
      description = "Host running gatus";
    };
    renderer = lib.mkOption {
      type = lib.types.str;
      default = "amoeba";
      description = "Host rendering the snapshots";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 16042;
      description = "Port the renderer serves snapshots on";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (hostName == cfg.source) {
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mapAttrsToList (
        _: instance: instance.port
      ) instances;
    })

    (lib.mkIf (hostName == cfg.renderer) {
      users.users.gatus-snapshot = {
        isSystemUser = true;
        group = "gatus-snapshot";
      };
      users.groups.gatus-snapshot = { };

      systemd.services.gatus-snapshot = {
        description = "render gatus snapshot";
        startAt = "*:0/15";
        restartIfChanged = false;
        environment = {
          JSDOM_PATH = "${nodeModules}/node_modules/jsdom";
          LANG = "en_GB.UTF-8";
        };
        serviceConfig = {
          Type = "oneshot";

          ExecStart = lib.mapAttrsToList (
            name: instance:
            "-${lib.getExe pkgs.nodejs} ${./snapshot/snapshot.mjs} http://${source.ipv4}:${toString instance.port}/ /run/gatus-snapshot/${name}"
          ) instances;
          TimeoutStartSec = "4min";

          RuntimeDirectory = "gatus-snapshot";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = true;
          UMask = "0022";

          MemoryMax = "1G";
          CPUWeight = 20;
          Nice = 10;

          User = "gatus-snapshot";
          Group = "gatus-snapshot";
          PrivateUsers = true;
          PrivateTmp = true;
          PrivateDevices = true;
          PrivateIPC = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          NoNewPrivileges = true;
          RemoveIPC = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "~@resources"
          ];
          SystemCallErrorNumber = "EPERM";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          IPAddressDeny = "any";
          IPAddressAllow = [
            source.ipv4
            source.ipv6
          ];
        };
      };

      services.caddy.virtualHosts."http://:${toString cfg.port}" = {
        listenAddresses = config.polaris.services.caddy.internalListenAddresses;
        extraConfig = ''
          @notSource not remote_ip ${source.ipv4} ${source.ipv6}
          handle @notSource {
            abort
          }
          handle {
            root * /run/gatus-snapshot
            file_server
          }
        '';
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        cfg.port
      ];
    })
  ];
}
