{
  config,
  lib,
  ...
}:
let
  cfg = config.polaris.services.docker;
in
{
  options.polaris.services.docker = {
    enable = lib.mkEnableOption "docker";
  };
  config = lib.mkIf cfg.enable {
    virtualisation = {
      containers = {
        enable = true;
        storage.settings.storage.driver = "btrfs";
      };
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
    users.users.nixos = {
      extraGroups = [
        "podman"
      ];
    };
  };
}
