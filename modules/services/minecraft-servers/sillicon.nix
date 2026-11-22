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
    url = "https://git.lunya.cc/SilliconMC/releases/releases/download/v${cfg.version}/Sillicon-${cfg.version}.mrpack";
    side = "server";
  };

  mods = pkgs.runCommand "sillicon-mods-${cfg.version}" { } ''
    cp -as ${pack}/mods $out
    ${lib.optionalString (!cfg.bluemap.enable) ''
      chmod u+w $out
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
    ${lib.optionalString (cfg.serverFiles != null) ''
      cp ${cfg.serverFiles}/config/lss-server-config.yaml $out/
    ''}
    ${lib.optionalString bluemapProxied (
      lib.concatStrings (
        lib.mapAttrsToList (name: text: ''
          install -Dm644 ${pkgs.writeText (baseNameOf name) text} $out/bluemap/${name}
        '') bluemapConfigs
      )
    )}
  '';

  tmux = "${lib.getBin pkgs.tmux}/bin/tmux";
  sock = mcCfg.managementSystem.tmux.socketPath "sillicon";
in
{
  options.polaris.services.minecraft-servers.sillicon = {
    enable = lib.mkEnableOption "Sillicon modded minecraft server";
    version = lib.mkOption {
      type = lib.types.str;
      default = "0.20.1-testing";
    };
    packHash = lib.mkOption {
      type = lib.types.str;
      default = "sha256-RyVH60R0Zaab8JV5KTaLfhokAAad+uhJk7Apm9VGluM=";
      description = "Hash of the server-side pack contents (fetchModrinthModpack output, not the .mrpack)";
    };
    serverFiles = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      description = "The pack repo's server/ directory";
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
        description = "Loopback port caddy serves the BlueMap webroot on, behind anubis";
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
        package = mcPkgs.neoforgeServers.neoforge-1_21_1-21_1_265;
        # user_jvm_args.txt from the pack is ignored, the launcher doesn't read it
        jvmOpts = lib.concatStringsSep " " [
          "-Xms4G"
          "-Xmx9G"
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
        ];
        openFirewall = true;

        symlinks.mods = mods;
        files = {
          config = configDir;
          defaultconfigs = "${pack}/defaultconfigs";
          journeymap = "${pack}/journeymap";
          kubejs = "${pack}/kubejs";
        };

        serverProperties = {
          server-port = 25565;
          motd = "\\u00A76Sillicon";
          max-players = 100;
          online-mode = true;
          enforce-secure-profile = false;
          white-list = true;
          enforce-whitelist = true;
          difficulty = "normal";
          spawn-protection = 0;
          allow-flight = true;
          view-distance = 8;
          simulation-distance = 5;
          entity-broadcast-range-percentage = 100;
          network-compression-threshold = 256;
          sync-chunk-writes = false;
          max-tick-time = -1;
          log-ips = true;
          max-chained-neighbor-updates = 1000000;
          enable-command-block = true;
        };
      };
    };

    systemd.services.minecraft-server-sillicon.serviceConfig = {
      TimeoutStopSec = lib.mkForce "10min";
    };

    networking.firewall.allowedUDPPorts = [
      cfg.voicechatPort
    ];

    services.caddy.virtualHosts = lib.mkIf bluemapProxied {
      "${cfg.bluemap.domain}".extraConfig = ''
        import encode

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
