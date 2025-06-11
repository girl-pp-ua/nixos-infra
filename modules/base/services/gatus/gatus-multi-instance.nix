{
  lib,
  pkgs,
  config,
  ...
}:
let
  settingsFormat = pkgs.formats.yaml { };
in
{
  options = with lib; {
    services.gatus.instances = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkEnableOption "this gatus instance" // {
              default = true;
            };
            port = mkOption {
              type = types.int;
            };
            settings = mkOption {
              type = types.submodule {
                freeformType = settingsFormat.type;
              };
              default = { };
            };
          };
        }
      );
      default = { };
    };
  };

  config = {
    systemd.services = (
      lib.mapAttrs' (
        name: value:
        lib.nameValuePair "gatus-${name}" {
          description = "Automated developer-oriented status page";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            DynamicUser = true;
            User = "gatus";
            Group = "gatus";
            Type = "simple";
            Restart = "on-failure";
            ExecStart = lib.getExe pkgs.gatus;
            StateDirectory = "gatus";
            SyslogIdentifier = "gatus";
            # TODO: upstream this
            AmbientCapabilities = "CAP_NET_RAW";
            CapabilityBoundingSet = "CAP_NET_RAW";
            NoNewPrivileges = true;
          };

          environment = {
            GATUS_CONFIG_PATH = settingsFormat.generate "gatus.yaml" (
              lib.recursiveUpdate value.settings {
                web.port = value.port;
              }
            );
          };
        }
      ) (lib.filterAttrs (name: value: value.enable) config.services.gatus.instances)
    );
  };
}
