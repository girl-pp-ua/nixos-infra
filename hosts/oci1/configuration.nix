{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../oci-amd-base.nix
    ./services.nix
  ];

  system.stateVersion = "25.05";

  networking.hostName = "oci1";
  networking.domain = "polaris";

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
