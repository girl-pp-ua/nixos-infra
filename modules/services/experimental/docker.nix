{
  config,
  lib,
  ...
}:
let
  cfg = config.polaris.services.experimental.docker;
in
{
  options.polaris.services.experimental.docker = {
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
        dockerSocket.enable = true;
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
