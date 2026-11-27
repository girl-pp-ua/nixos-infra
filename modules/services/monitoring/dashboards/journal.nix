# journal browser
{ pkgs, ... }:
let
  ds = {
    type = "victoriametrics-logs-datasource";
    uid = "victorialogs";
  };
  filter = "host:$host unit:$unit priority:$priority $search";
  fieldVar = name: query: {
    inherit name;
    label = name;
    type = "query";
    datasource = ds;
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
    refresh = 2; # on time range change
    sort = 1;
  };
in
pkgs.writeText "journal.json" (
  builtins.toJSON {
    uid = "journal";
    title = "Journal";
    tags = [ "logs" ];
    schemaVersion = 39;
    refresh = "1m";
    time = {
      from = "now-1h";
      to = "now";
    };
    templating.list = [
      (fieldVar "host" "*")
      (fieldVar "unit" "host:$host")
      (fieldVar "priority" "host:$host unit:$unit")
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
      {
        type = "timeseries";
        title = "Volume by priority";
        datasource = ds;
        gridPos = {
          x = 0;
          y = 0;
          w = 24;
          h = 6;
        };
        targets = [
          {
            refId = "A";
            editorMode = "code";
            queryType = "statsRange";
            expr = "${filter} | stats by (priority) count() hits";
            legendFormat = "{{priority}}";
          }
        ];
        fieldConfig.defaults.custom = {
          drawStyle = "bars";
          fillOpacity = 80;
          stacking.mode = "normal";
        };
      }
      {
        type = "logs";
        title = "Logs";
        datasource = ds;
        gridPos = {
          x = 0;
          y = 6;
          w = 24;
          h = 24;
        };
        targets = [
          {
            refId = "A";
            editorMode = "code";
            queryType = "instant";
            expr = filter;
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
      }
    ];
  }
)
