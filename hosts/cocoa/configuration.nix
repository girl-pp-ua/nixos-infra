{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.05";

  fileSystems =
    let
      btrfsOptions = [
        "noatime"
        "compress=zstd"
      ];
    in
    {
      "/".options = btrfsOptions;
      "/home".options = btrfsOptions;
      "/nix".options = btrfsOptions;
      "/swap".options = [ "noatime" ];
      "/boot".options = [ "noatime" ];
    };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 8 * 1024; # 8 GiB
    }
  ];

  networking = {
    useDHCP = false;
    interfaces.eth0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "45.8.201.26";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      address = "45.8.201.1";
      interface = "eth0";
    };
    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };
}
