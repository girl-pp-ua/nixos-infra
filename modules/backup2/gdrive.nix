{ config, lib, ... }:
{
  config = lib.mkIf config.polaris.backup2.enable {
    polaris.backup2 = {
      repository = "rclone:gdrive:backups/restic";
      rcloneConfigFile = config.security.nix-secrets.templates."rclone-gdrive.conf".path;
      packSize = 64; # (drive is slow with many small files)
    };

    security.nix-secrets = {
      secrets = {
        "backup/gdrive/clientId" = { };
        "backup/gdrive/clientSecret" = { };
        "backup/gdrive/token" = { };
      };
      templates."rclone-gdrive.conf".content = ''
        [gdrive]
        type = drive
        scope = drive.file
        client_id = ${config.security.nix-secrets.secrets."backup/gdrive/clientId".templateKey}
        client_secret = ${config.security.nix-secrets.secrets."backup/gdrive/clientSecret".templateKey}
        token = ${config.security.nix-secrets.secrets."backup/gdrive/token".templateKey}
      '';
    };
  };
}
