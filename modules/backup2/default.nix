{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.polaris.backup2;
  sqliteDir = "/var/backup/sqlite";
  pgDir = config.services.postgresqlBackup.location;
in
{
  imports = [
    ./restic.nix
    ./gdrive.nix
  ];

  options.polaris.backup2 = {
    enable = lib.mkEnableOption "backups" // {
      default = true;
    };
    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Files/directories to back up";
    };
    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Absolute path patterns to skip in backups";
    };
    postgresql.databases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "PostgreSQL databases to back up";
    };
    sqlite = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SQLite databases to back up";
    };
    prepare = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Shell commands run as root before every backup";
    };
    prepareUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Units started and waited for before every backup";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        polaris.backup2.paths = [
          # host keys
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];

        systemd.services.backup2-prepare = {
          description = "Prepare for backups (database dumps etc)";
          wants = cfg.prepareUnits;
          after = cfg.prepareUnits;
          serviceConfig.Type = "oneshot";
          script = ''
            failed=0
            ${lib.concatMapStrings (cmd: ''
              ( ${cmd} ) || { echo ${lib.escapeShellArg "backup prepare step failed: ${cmd}"} >&2; failed=1; }
            '') cfg.prepare}
            exit $failed
          '';
        };
      }

      (lib.mkIf (cfg.postgresql.databases != [ ]) {
        services.postgresqlBackup = {
          enable = true;
          inherit (cfg.postgresql) databases;
          compression = "none"; # (as plain sql)
          startAt = [ ]; # (only run by backup2-prepare)
        };
        polaris.backup2 = {
          paths = [ pgDir ];
          prepareUnits = map (db: "postgresqlBackup-${db}.service") cfg.postgresql.databases;
        };
      })

      (lib.mkIf (cfg.sqlite != [ ]) {
        polaris.backup2 = {
          paths = [ sqliteDir ];
          exclude = lib.concatMap (db: [
            db
            "${db}-wal"
            "${db}-shm"
            "${db}-journal"
          ]) cfg.sqlite;
          prepare = map (db: ''
            if [ -e ${db} ]; then
              mkdir -p ${sqliteDir}${dirOf db}
              ${lib.getExe pkgs.sqlite} -readonly ${db} ".backup '${sqliteDir}${db}.tmp'"
              mv ${sqliteDir}${db}.tmp ${sqliteDir}${db}
            fi
          '') cfg.sqlite;
        };
        systemd.tmpfiles.rules = [ "d ${sqliteDir} 0700 root root -" ];
      })
    ]
  );
}
