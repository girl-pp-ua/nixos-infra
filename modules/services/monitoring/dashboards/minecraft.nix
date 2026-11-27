# jobs from the minecraft-servers modules (minecraft-status, minecraft-jvm)
{ pkgs, ... }:
let
  ds = {
    type = "prometheus";
    uid = "victoriametrics";
  };
  sel = ''instance="$instance"'';
  logsDs = {
    type = "victoriametrics-logs-datasource";
    uid = "victorialogs";
  };
  logsSel = ''server:~".+" server:$server'';
  status = metric: "max without (server_version) (${metric}{${sel}})";
  chatFilter = ''${logsSel} logger:"net.minecraft.server.MinecraftServer" _msg:~"^(\\[Not Secure\\] )?<[^>]+> "'';
  logs = y: x: w: h: title: expr: {
    type = "logs";
    inherit title;
    datasource = logsDs;
    gridPos = {
      inherit
        x
        y
        w
        h
        ;
    };
    targets = [
      {
        refId = "A";
        editorMode = "code";
        queryType = "instant";
        inherit expr;
        maxLines = 1000;
      }
    ];
    options = {
      showTime = true;
      wrapLogMessage = true;
      sortOrder = "Descending";
      enableLogDetails = true;
      dedupStrategy = "none";
    };
  };
  logsVar = name: query: {
    inherit name;
    label = name;
    type = "query";
    datasource = logsDs;
    query = {
      refId = name;
      type = "fieldValue";
      field = name;
      inherit query;
      limit = 1000;
    };
    multi = true;
    includeAll = true;
    allValue = "*";
    current = {
      text = [ "All" ];
      value = [ "$__all" ];
    };
    refresh = 2;
    sort = 1;
  };
  target = expr: legendFormat: {
    refId = legendFormat;
    inherit expr legendFormat;
  };
  panel = type: title: gridPos: unit: targets: {
    inherit
      type
      title
      gridPos
      targets
      ;
    datasource = ds;
    fieldConfig.defaults.unit = unit;
  };
  stat =
    x: title: unit: expr:
    panel "stat" title {
      inherit x;
      y = 0;
      w = 4;
      h = 4;
    } unit [ (target expr title) ]
    // {
      options.reduceOptions.calcs = [ "lastNotNull" ];
    };
  graph =
    x: y: title: unit: targets:
    panel "timeseries" title {
      inherit x y;
      w = 12;
      h = 8;
    } unit targets;
in
pkgs.writeText "minecraft.json" (
  builtins.toJSON {
    uid = "minecraft";
    title = "Minecraft";
    tags = [ "minecraft" ];
    schemaVersion = 39;
    refresh = "1m";
    time = {
      from = "now-24h";
      to = "now";
    };
    templating.list = [
      {
        name = "instance";
        type = "query";
        datasource = ds;
        query = "label_values(minecraft_status_healthy, instance)";
        refresh = 1;
      }
      (logsVar "server" "*")
      (logsVar "level" "server:$server")
      {
        name = "search";
        label = "search";
        type = "textbox";
        query = "";
        current = {
          text = "";
          value = "";
        };
      }
    ];
    panels = [
      (
        stat 0 "Status" "none" (status "minecraft_status_healthy")
        // {
          fieldConfig.defaults = {
            mappings = [
              {
                type = "value";
                options = {
                  "0" = {
                    text = "down";
                    color = "red";
                  };
                  "1" = {
                    text = "up";
                    color = "green";
                  };
                };
              }
            ];
            color.mode = "thresholds";
          };
        }
      )
      (stat 4 "Players" "none" (status "minecraft_status_players_online_count"))
      (stat 8 "MSPT" "ms" "minecraft_tick_time_milliseconds{${sel}}")
      (stat 12 "TPS" "none" "clamp_max(1000 / minecraft_tick_time_milliseconds{${sel}}, 20)")
      (stat 16 "Heap used" "bytes" ''jvm_memory_used_bytes{${sel},job="minecraft-jvm",area="heap"}'')
      (stat 20 "Ping" "s" (status "minecraft_status_response_time_seconds"))

      (graph 0 4 "Players online" "none" [
        (target (status "minecraft_status_players_online_count") "online")
      ])
      (
        graph 12 4 "Tick time" "ms" [ (target "minecraft_tick_time_milliseconds{${sel}}" "mspt") ]
        // {
          fieldConfig.defaults = {
            unit = "ms";
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 50;
                }
              ];
            };
            custom.thresholdsStyle.mode = "line";
          };
        }
      )
      (graph 0 12 "Heap" "bytes" [
        (target ''jvm_memory_used_bytes{${sel},job="minecraft-jvm",area="heap"}'' "used")
        (target ''jvm_memory_committed_bytes{${sel},job="minecraft-jvm",area="heap"}'' "committed")
        (target ''jvm_memory_max_bytes{${sel},job="minecraft-jvm",area="heap"}'' "max")
      ])
      (graph 12 12 "GC time" "percentunit" [
        (target ''rate(jvm_gc_collection_seconds_sum{${sel},job="minecraft-jvm"}[5m])'' "{{gc}}")
      ])
      (graph 0 20 "CPU" "none" [
        (target ''rate(process_cpu_seconds_total{${sel},job="minecraft-jvm"}[5m])'' "cores")
      ])
      (graph 12 20 "Threads" "none" [
        (target ''jvm_threads_current{${sel},job="minecraft-jvm"}'' "threads")
      ])

      (logs 28 0 12 12 "Chat" chatFilter)
      (logs 28 12 12 12 "Joins and leaves" ''${logsSel} _msg:~"(joined|left) the game$"'')
      {
        type = "timeseries";
        title = "Log volume by level";
        datasource = logsDs;
        gridPos = {
          x = 0;
          y = 40;
          w = 24;
          h = 6;
        };
        targets = [
          {
            refId = "A";
            editorMode = "code";
            queryType = "statsRange";
            expr = "${logsSel} | stats by (level) count() hits";
            legendFormat = "{{level}}";
          }
        ];
        fieldConfig.defaults.custom = {
          drawStyle = "bars";
          fillOpacity = 80;
          stacking.mode = "normal";
        };
      }
      (logs 46 0 24 20 "Server log" "${logsSel} level:$level $search")
    ];
  }
)
