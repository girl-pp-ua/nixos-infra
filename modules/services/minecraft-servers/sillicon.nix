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

  # silliconmc-jarjar is an FML locator service;
  # those are only picked up from -DlegacyClassPath
  server =
    let
      base = mcPkgs.neoforgeServers.neoforge-1_21_1-21_1_265;
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

  configDir =
    pkgs.runCommand "sillicon-config-${cfg.version}" { nativeBuildInputs = [ pkgs.unzip ]; }
      ''
        cp -r ${pack}/config $out
        chmod -R u+w $out
        ${
          if cfg.serverFiles != null then
            ''
              cp ${cfg.serverFiles}/config/lss-server-config.yaml $out/
            ''
          else
            # the mod's own template, generation off and radius 128 so LODs only come from
            # pregenerated terrain. its built-in default is generation on at 512 chunks
            ''
              unzip -p ${pack}/mods/lod-server-support-*.jar dev/vox/lss/settings/server.yaml \
                | sed -E \
                  -e 's/^(  enabled: )true( # Generate missing terrain)/\1false\2/' \
                  -e 's/^(    default_chunks: )512/\1128/' \
                  -e 's/^(      "minecraft:(overworld|the_end)": )512/\1128/' \
                > $out/lss-server-config.yaml
              [ "$(grep -cE '^  enabled: false # Generate|: 128 #' $out/lss-server-config.yaml)" = 4 ]
            ''
        }
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

  tmux = "${lib.getBin pkgs.tmux}/bin/tmux";
  sock = mcCfg.managementSystem.tmux.socketPath "sillicon";
in
{
  options.polaris.services.minecraft-servers.sillicon = {
    enable = lib.mkEnableOption "Sillicon modded minecraft server";
    version = lib.mkOption {
      type = lib.types.str;
      default = "0.20.8";
    };
    packHash = lib.mkOption {
      type = lib.types.str;
      default = "sha256-mMWBA8pzlBDNly29XRZdu6UGGTC71io/XV/C+1d0G5U=";
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
          defaultconfigs = "${pack}/defaultconfigs";
          journeymap = "${pack}/journeymap";
          kubejs = "${pack}/kubejs";
        };
        extraStartPre = ''
          mkdir -p config
          cp -rT --no-preserve=mode,ownership ${configDir} config
        '';

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
