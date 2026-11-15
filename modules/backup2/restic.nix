{
  config,
  lib,
  ...
}:
let
  cfg = config.polaris.backup2;
  host = config.networking.hostName;

  repo = {
    repository = "${cfg.repository}/${host}";
    passwordFile = config.sops.secrets."backup/restic/${host}/password".path;
    inherit (cfg) rcloneConfigFile environmentFile;
  };
  common = {
    environment = lib.optionalAttrs (cfg.packSize != null) {
      RESTIC_PACK_SIZE = toString cfg.packSize;
    };
    serviceConfig = {
      Nice = 10;
      IOSchedulingClass = "idle";
      CPUWeight = 20;
    };
  };
in
{
  options.polaris.backup2 = {
    repository = lib.mkOption {
      type = lib.types.str;
      example = "rclone:remote:backups/restic";
      description = "Base restic repository, the host name is appended.";
    };
    rcloneConfigFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Credentials for the destination (s3, b2, ...).";
    };
    packSize = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "RESTIC_PACK_SIZE in MiB";
    };
    keep = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = {
        daily = 7;
        weekly = 4;
        monthly = 12;
        yearly = 3;
      };
      description = "Retention";
    };
  };

  config = lib.mkIf cfg.enable {
    services.restic.backups = {
      backup2 = repo // {
        initialize = true;
        inherit (cfg) exclude;
        # whitelisted paths that don't exist (yet) are skipped
        dynamicFilesFrom = ''
          for p in ${lib.escapeShellArgs (lib.unique cfg.paths)}; do
            if [ -e "$p" ]; then echo "$p"; else echo "backup2: skipping missing path $p" >&2; fi
          done
        '';
        extraBackupArgs = [
          "--exclude-caches"
          "--retry-lock 30m"
        ];
        timerConfig = {
          OnCalendar = "04:00";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };
      backup2-maintenance = repo // {
        createWrapper = false;
        pruneOpts = [
          "--group-by host"
          "--retry-lock 2h"
        ]
        ++ lib.mapAttrsToList (k: v: "--keep-${k} ${toString v}") cfg.keep;
        runCheck = true;
        checkOpts = [
          "--read-data-subset 5%"
          "--retry-lock 2h"
        ];
        timerConfig = {
          OnCalendar = "Sun 07:00";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };
    };

    systemd.services = {
      restic-backups-backup2 = lib.mkMerge [
        common
        {
          wants = [ "backup2-prepare.service" ];
          after = [ "backup2-prepare.service" ];
        }
      ];
      restic-backups-backup2-maintenance = common;
    };

    sops.secrets."backup/restic/${host}/password" = { };
  };
}
