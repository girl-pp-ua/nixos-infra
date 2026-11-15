{ config, lib, ... }:
{
  config = lib.mkIf config.polaris.backup2.enable {
    polaris.backup2 = {
      repository = "rclone:gdrive:backups/restic";
      rcloneConfigFile = config.sops.templates."rclone-gdrive.conf".path;
      packSize = 64; # (drive is slow with many small files)
    };

    sops = {
      secrets = {
        "backup/gdrive/clientId" = { };
        "backup/gdrive/clientSecret" = { };
        "backup/gdrive/token" = { };
      };
      templates."rclone-gdrive.conf".content = ''
        [gdrive]
        type = drive
        scope = drive.file
        client_id = ${config.sops.placeholder."backup/gdrive/clientId"}
        client_secret = ${config.sops.placeholder."backup/gdrive/clientSecret"}
        token = ${config.sops.placeholder."backup/gdrive/token"}
      '';
    };
  };
}
