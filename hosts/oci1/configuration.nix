{ ... }:
{
  system.stateVersion = "25.05";

  imports = [
    ./hardware-configuration.nix
    ../../modules/host_shared/oci-amd-base.nix
  ];

  fileSystems = {
    "/data" = {
      device = "/dev/disk/by-label/data";
      fsType = "btrfs";
      options = [
        "noatime"
        "compress=zstd:1"
      ];
    };
  };

  # move caddy data to /data/caddy
  # services.caddy.extraConfig = ''
  #   {
  #     storage file_system {
  #       root /data/caddy
  #     }
  #   }
  # '';
}
