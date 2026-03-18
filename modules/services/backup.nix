{ config, lib, ... }:
let
  cfg = config.polaris.services.backup;
in
{
  options.polaris.services.backup = {
    enable = lib.mkEnableOption "backup";
    repo = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The backup repository";
    };
  };

  config = lib.mkIf cfg.enable {
    services.borgbackup.jobs = {
      weekly = {
        startAt = "weekly";
        repo = cfg.repo;
        paths = [
          "/home"
          "/root"
          "/var/lib"
        ];
        exclude = [
          "/home/*/.cache"
          "/root/.cache"
          "/root/.nix-channels"
          "/nix"
          "/var/lib/steam-headless"
        ];
        removableDevice = true;
        prune.keep = {
          within = "7d"; # keep everything from the last week
          weekly = 4; # then 1 per week going back 4 weeks
          monthly = 6; # then 1 per month going back 6 months
        };
        persistentTimer = true;
        encryption = {
          mode = "repokey";
          passCommand = "cat ${config.sops.secrets."borg/data0/passphrase".path}";
        };
        compression = "auto,zstd";
      };
    };

    sops.secrets = {
      "borg/data0/passphrase" = { };
    };
  };
}
