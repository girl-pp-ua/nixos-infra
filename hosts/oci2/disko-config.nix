{
  disko.devices = {
    disk.main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            name = "ESP";
            priority = 1;
            start = "1M";
            end = "1024M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          nixos = {
            name = "nixos";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = ["-f"];
              mountpoint = "/partition-root";
              subvolumes = let
                mountOptions = [
                  "noatime"
                ];
              in {
                "/root" = {
                  mountpoint = "/";
                  inherit mountOptions;
                };
                "/nix" = {
                  mountpoint = "/nix";
                  inherit mountOptions;
                };
                "/home" = {
                  mountpoint = "/home";
                  inherit mountOptions;
                };
              };
            };
          };
        };
      };
    };
  };
}