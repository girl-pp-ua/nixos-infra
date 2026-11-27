{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.polaris.services.minecraft-servers.sillicon;
  mcPkgs = inputs.nix-minecraft.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  mcCfg = config.services.minecraft-servers;
  dataDir = "${mcCfg.dataDir}/sillicon";

  pack = mcPkgs.fetchModrinthModpack {
    pname = "sillicon";
    inherit (cfg) version packHash;
    # TODO drop -server-fix on the next release
    url = "https://git.lunya.cc/SilliconMC/releases/releases/download/v${cfg.version}/Sillicon-${cfg.version}-server-fix.mrpack";
    side = "server";
  };

  # silliconmc-jarjar is an FML locator service;
  # those are only picked up from -DlegacyClassPath
  server =
    let
      base = mcPkgs.neoforgeServers.neoforge-1_21_1-21_1_265.override {
        jre_headless = cfg.java;
      };
    in
    pkgs.runCommand "sillicon-${base.name}" { meta.mainProgram = "minecraft-server"; } ''
      jar=$(echo ${pack}/mods/silliconmc-jarjar-*.jar)
      args=$(find ${base}/libraries -name unix_args.txt)
      mkdir -p $out/bin
      sed "s|-DlegacyClassPath=[^ ]*|&:$jar|" "$args" > $out/unix_args.txt
      grep -qF "$jar" $out/unix_args.txt
      sed "s|@$args|@$out/unix_args.txt|" ${lib.getExe base} > $out/bin/minecraft-server
      grep -qF "@$out/unix_args.txt" $out/bin/minecraft-server
      chmod +x $out/bin/minecraft-server
    '';

  mods = pkgs.runCommand "sillicon-mods-${cfg.version}" { } ''
    cp -as ${pack}/mods $out
    chmod u+w $out
    rm $out/silliconmc-jarjar-*.jar
    ${lib.optionalString (!cfg.bluemap.enable) ''
      find $out -iname '*bluemap*' -delete
    ''}
  '';

  bluemapProxied = cfg.bluemap.enable && cfg.bluemap.domain != null;
  bluemapWebroot = "/var/lib/sillicon-bluemap";

  # caddy serves the webroot, so the in-game webserver stays off and live
  # player/marker data gets written to storage instead
  bluemapConfigs = {
    "webserver.conf" = "enabled: false";
    "webapp.conf" = ''webroot: "${bluemapWebroot}"'';
    "storages/file.conf" = ''
      storage-type: file
      root: "${bluemapWebroot}/maps"
      compression: gzip
    '';
    "plugin.conf" = ''
      hidden-game-modes: [ "spectator" ]
      write-markers-interval: 10
      write-players-interval: 3
    '';
  };

  configDir = pkgs.runCommand "sillicon-config-${cfg.version}" { } ''
    cp -r ${pack}/config $out
    chmod -R u+w $out
    ${lib.optionalString bluemapProxied (
      lib.concatStrings (
        lib.mapAttrsToList (name: text: ''
          install -Dm644 ${pkgs.writeText (baseNameOf name) text} $out/bluemap/${name}
        '') bluemapConfigs
      )
    )}

    # make bluemap render all chunks :3
    sed -i 's/^min-inhabited-time: .*/min-inhabited-time: 0/' $out/bluemap/maps/*.conf
    [ "$(grep -l '^min-inhabited-time: 0$' $out/bluemap/maps/*.conf | wc -l)" = "$(ls $out/bluemap/maps/*.conf | wc -l)" ]
  '';

  jmxAgent = pkgs.fetchurl {
    url = "https://github.com/prometheus/jmx_exporter/releases/download/1.7.0/jmx_prometheus_javaagent-1.7.0.jar";
    hash = "sha256-CthDJhxWfRkkoBfVQuFMQPKv/1I9lAwl7gAHQv3ks6k=";
  };
  jmxConfig = pkgs.writeText "sillicon-jmx.json" (
    builtins.toJSON {
      includeObjectNames = [ "net.minecraft.server:type=Server" ];
      rules = [
        {
          pattern = "net.minecraft.server<type=Server><>averageTickTime";
          name = "minecraft_tick_time_milliseconds";
          help = "average tick time over the last 100 ticks";
          type = "GAUGE";
        }
      ];
    }
  );

  tmux = "${lib.getBin pkgs.tmux}/bin/tmux";
  sock = mcCfg.managementSystem.tmux.socketPath "sillicon";
in
{
  options.polaris.services.minecraft-servers.sillicon = {
    enable = lib.mkEnableOption "Sillicon modded minecraft server";
    version = lib.mkOption {
      type = lib.types.str;
      default = "0.23.1";
    };
    packHash = lib.mkOption {
      type = lib.types.str;
      default = "sha256-C2W8uzFQ1iD+T+qCsLbhkuG4Grd1GlOEz3CDrf765Fc=";
    };
    java = lib.mkOption {
      type = lib.types.package;
      default = pkgs.graalvmPackages.graalvm-oracle;
      defaultText = lib.literalExpression "pkgs.graalvmPackages.graalvm-oracle";
    };
    monitoring = {
      enable = lib.mkEnableOption "monitoring exporters" // {
        default = true;
      };
      jvmPort = lib.mkOption {
        type = lib.types.port;
        default = 16160;
      };
      statusPort = lib.mkOption {
        type = lib.types.port;
        default = 16161;
      };
    };
    voicechatPort = lib.mkOption {
      type = lib.types.port;
      default = 24454;
    };
    bluemap = {
      enable = lib.mkEnableOption "BlueMap" // {
        default = true;
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8100;
      };
      domain = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.minecraft-servers = {
      enable = true;
      eula = true;
      servers.sillicon = {
        enable = true;
        package = server;
        # user_jvm_args.txt from the pack is ignored, the launcher doesn't read it
        jvmOpts = lib.concatStringsSep " " (
          [
            "-Xms6G"
            "-Xmx10G"
            "-XX:+UseG1GC"
            "-XX:+ParallelRefProcEnabled"
            "-XX:MaxGCPauseMillis=200"
            "-XX:+UnlockExperimentalVMOptions"
            "-XX:+DisableExplicitGC"
            "-XX:G1NewSizePercent=30"
            "-XX:G1MaxNewSizePercent=40"
            "-XX:G1HeapRegionSize=8M"
            "-XX:G1ReservePercent=20"
            "-XX:G1HeapWastePercent=5"
            "-XX:G1MixedGCCountTarget=4"
            "-XX:InitiatingHeapOccupancyPercent=15"
            "-XX:G1MixedGCLiveThresholdPercent=90"
            "-XX:G1RSetUpdatingPauseTimePercent=5"
            "-XX:SurvivorRatio=32"
            "-XX:+PerfDisableSharedMem"
            "-XX:MaxTenuringThreshold=1"
            "-XX:+UseStringDeduplication"
            "-XX:+UseCompactObjectHeaders"
            "-XX:+UseTransparentHugePages"
          ]
          ++ lib.optional cfg.monitoring.enable "-javaagent:${jmxAgent}=${toString cfg.monitoring.jvmPort}:${jmxConfig}"
        );
        openFirewall = true;

        symlinks.mods = mods;
        files = {
          defaultconfigs = "${pack}/defaultconfigs";
          journeymap = "${pack}/journeymap";
          kubejs = "${pack}/kubejs";
        };
        extraStartPre = ''
          mkdir -p config
          cp -rT --no-preserve=mode,ownership ${configDir} config
          # the pack runs LSS on the mod's defaults, drop the file it writes so a newer
          # jar's defaults apply
          rm -f config/lss-server-config.yaml
        '';

        serverProperties = {
          server-port = 25565;
          motd = "\\u00A76Sillicon [STAGING SERVER]";
          max-players = 100;
          online-mode = true;
          enforce-secure-profile = false;
          white-list = true;
          enforce-whitelist = true;
          difficulty = "normal";
          spawn-protection = 0;
          allow-flight = true;
          view-distance = 14;
          simulation-distance = 5;
          entity-broadcast-range-percentage = 100;
          network-compression-threshold = 256;
          sync-chunk-writes = false;
          max-tick-time = -1;
          log-ips = true;
          max-chained-neighbor-updates = 1000000;
          enable-command-block = true;
          enable-jmx-monitoring = cfg.monitoring.enable;
        };
      };
    };

    systemd.services.minecraft-server-sillicon.serviceConfig = {
      TimeoutStopSec = lib.mkForce "10min";
      NoNewPrivileges = true;
      RemoveIPC = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ dataDir ] ++ lib.optional bluemapProxied bluemapWebroot;
      SystemCallFilter = [ "@system-service" ];
      SystemCallErrorNumber = "EPERM";
    };

    # export player count/ping
    systemd.services.sillicon-status-exporter = lib.mkIf cfg.monitoring.enable {
      description = "Prometheus exporter for the Sillicon server status";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe pkgs.mc-monitor)
          "export-for-prometheus"
          "-servers"
          "localhost:${toString mcCfg.servers.sillicon.serverProperties.server-port}"
          "-port"
          (toString cfg.monitoring.statusPort)
          "-timeout"
          "10s"
        ];
        DynamicUser = true;
        Restart = "on-failure";
        CapabilityBoundingSet = "";
        PrivateDevices = true;
        ProtectHome = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        SystemCallFilter = [ "@system-service" ];
      };
    };

    polaris.services.monitoring.exports = lib.mkIf cfg.monitoring.enable {
      minecraft-jvm.port = cfg.monitoring.jvmPort;
      minecraft-status.port = cfg.monitoring.statusPort;
    };

    # logs/latest.log to victorialogs
    services.fluent-bit.settings = lib.mkIf cfg.monitoring.enable {
      parsers = [
        {
          name = "minecraft";
          format = "regex";
          # [27Nov2026 00:14:32.770] [Server thread/INFO] [net.minecraft.server.MinecraftServer/]: msg
          regex = ''^\[[^\]]+\] \[[^\]]*/(?<level>[A-Z]+)\] \[(?<logger>[^\]]*?)/?\]: (?<message>[\s\S]*?)\s*\z'';
        }
      ];
      multiline_parsers = [
        {
          name = "minecraft";
          type = "regex";
          flush_timeout = 1000;
          rules = [
            {
              state = "start_state";
              regex = ''/^\[\d{2}\w{3}\d{4} /'';
              next_state = "cont";
            }
            {
              state = "cont";
              regex = ''/^(?!\[\d{2}\w{3}\d{4} )/'';
              next_state = "cont";
            }
          ];
        }
      ];
      pipeline = {
        inputs = [
          {
            name = "tail";
            tag = "minecraft.sillicon";
            path = "${dataDir}/logs/latest.log";
            db = "/var/lib/fluent-bit/minecraft-sillicon.db";
            "multiline.parser" = "minecraft";
            mem_buf_limit = "8M";
          }
        ];
        filters = [
          {
            name = "parser";
            match = "minecraft.sillicon";
            key_name = "log";
            parser = "minecraft";
          }
        ];
        outputs = [
          {
            name = "loki";
            match = "minecraft.sillicon";
            host = config.polaris.services.monitoring.agent.ingestHost;
            port = config.polaris.services.monitoring.server.ingestPort;
            uri = "/insert/loki/api/v1/push";
            compress = "gzip";
            labels = "host=${config.networking.hostName}, server=sillicon, level=$level, logger=$logger";
            remove_keys = "level, logger";
            drop_single_key = "raw";
            retry_limit = 10;
          }
        ];
      };
    };
    systemd.services.fluent-bit.serviceConfig.SupplementaryGroups = lib.mkIf cfg.monitoring.enable [
      mcCfg.group
    ];

    networking.firewall.allowedUDPPorts = [
      cfg.voicechatPort
      # sable UDP transport
      mcCfg.servers.sillicon.serverProperties.server-port
    ];

    services.caddy.virtualHosts = lib.mkIf bluemapProxied {
      "${cfg.bluemap.domain}".extraConfig = ''
        import encode

        redir / /bluemap/
        redir /bluemap /bluemap/

        @anubis not client_ip ${lib.concatStringsSep " " config.polaris.trustedNetworks}
        handle @anubis {
          reverse_proxy unix/${config.services.anubis.instances.bluemap.settings.BIND} {
            header_up X-Real-IP {client_ip}
          }
        }

        reverse_proxy 127.0.0.1:${toString cfg.bluemap.port}
      '';

      # tiles are stored as .prbm.gz and get served as .prbm with Content-Encoding,
      # see https://bluemap.bluecolored.de/wiki/webserver/ExternalWebserversFile.html
      "http://:${toString cfg.bluemap.port}" = {
        listenAddresses = [
          "127.0.0.1"
          "::1"
        ];
        extraConfig = ''
          root * ${bluemapWebroot}

          handle_path /bluemap/* {
            file_server

            @gz path /maps/*/textures.json *.prbm
            handle @gz {
              try_files {path}.gz =204
              header Content-Encoding gzip
            }

            @tiles path */tiles/*
            handle @tiles {
              try_files {path} =204
            }
          }
        '';
      };
    };

    services.anubis.instances = lib.mkIf bluemapProxied {
      bluemap.settings = {
        TARGET = "http://127.0.0.1:${toString cfg.bluemap.port}";
        SERVE_ROBOTS_TXT = true;
      };
    };

    # setgid so everything bluemap writes stays readable by caddy
    systemd.tmpfiles.rules = lib.mkIf bluemapProxied [
      "d ${bluemapWebroot} 2750 ${mcCfg.user} ${config.services.caddy.group} - -"
    ];
    # to reach anubis' socket
    users.users.caddy.extraGroups = lib.mkIf bluemapProxied [
      config.services.anubis.instances.bluemap.group
    ];

    polaris.backup2 = {
      paths = [ "${dataDir}/world" ];
      prepare = [
        "${tmux} -S ${sock} send-keys C-u 'save-all flush' Enter || true"
      ];
    };
  };
}
