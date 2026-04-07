{ ... }:
{
  system.stateVersion = "25.05";

  imports = [
    ./hardware-configuration.nix
    ../oci-amd-base.nix
    ./services.nix
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
}
