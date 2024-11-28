{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ../oci-amd-base/configuration.nix
  ];

  fileSystems = {
    "/data" = {
      device = "/dev/disk/by-label/data";
      fsType = "btrfs";
      options = [ "noatime" "compress=zstd:1" ];
    };
  };
}