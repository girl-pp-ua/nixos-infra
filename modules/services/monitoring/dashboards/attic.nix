{ pkgs, config, ... }:
let
  ds = {
    type = "grafana-postgresql-datasource";
    uid = "attic";
  };
  query = format: rawSql: {
    datasource = ds;
    inherit format rawSql;
    rawQuery = true;
    editorMode = "code";
    refId = "A";
  };
  stat = x: title: unit: rawSql: {
    type = "stat";
    inherit title;
    datasource = ds;
    gridPos = {
      inherit x;
      y = 0;
      w = 6;
      h = 4;
    };
    targets = [ (query "table" rawSql) ];
    fieldConfig.defaults.unit = unit;
    options.reduceOptions.calcs = [ "lastNotNull" ];
  };
  table = x: title: rawSql: {
    type = "table";
    inherit title;
    datasource = ds;
    gridPos = {
      inherit x;
      y = 12;
      w = 12;
      h = 12;
    };
    targets = [ (query "table" rawSql) ];
    fieldConfig.overrides = [
      {
        matcher = {
          id = "byName";
          options = "size";
        };
        properties = [
          {
            id = "unit";
            value = "bytes";
          }
        ];
      }
    ];
  };
  shortPath = "regexp_replace(o.store_path, '^/nix/store/[a-z0-9]{32}-', '')";
in
pkgs.writeText "attic.json" (
  builtins.toJSON {
    uid = "attic";
    title = "Attic";
    tags = [ "attic" ];
    schemaVersion = 39;
    time = {
      from = "now-30d";
      to = "now";
    };
    panels = [
      (stat 0 "Store paths" "short" "SELECT count(*) FROM object")
      (stat 6 "Uncompressed" "bytes" "SELECT sum(nar_size) FROM nar")
      (stat 12 "Stored" "bytes" "SELECT sum(file_size) FROM chunk")
      (stat 18 "Stored / uncompressed" "percentunit"
        "SELECT (SELECT sum(file_size) FROM chunk)::float / nullif((SELECT sum(nar_size) FROM nar), 0)"
      )
      {
        type = "timeseries";
        title = "Paths pushed per day";
        datasource = ds;
        gridPos = {
          x = 0;
          y = 4;
          w = 12;
          h = 8;
        };
        targets = [
          (query "time_series" ''
            SELECT date_trunc('day', created_at) AS time, count(*) AS pushed
            FROM object WHERE $__timeFilter(created_at) GROUP BY 1 ORDER BY 1
          '')
        ];
        fieldConfig.defaults.custom.drawStyle = "bars";
      }
      {
        type = "timeseries";
        title = "Free disk (${config.networking.hostName})";
        datasource = {
          type = "prometheus";
          uid = "victoriametrics";
        };
        gridPos = {
          x = 12;
          y = 4;
          w = 12;
          h = 8;
        };
        targets = [
          {
            refId = "A";
            expr = ''node_filesystem_avail_bytes{instance="${config.networking.hostName}",mountpoint="/"}'';
            legendFormat = "free";
          }
        ];
        fieldConfig.defaults.unit = "bytes";
      }
      (table 0 "Largest paths" ''
        SELECT ${shortPath} AS path, n.nar_size AS size, o.created_at AS pushed
        FROM object o JOIN nar n ON n.id = o.nar_id ORDER BY n.nar_size DESC LIMIT 25
      '')
      (table 12 "Latest pushes" ''
        SELECT o.created_at AS pushed, ${shortPath} AS path, n.nar_size AS size
        FROM object o JOIN nar n ON n.id = o.nar_id ORDER BY o.created_at DESC LIMIT 25
      '')
    ];
  }
)
