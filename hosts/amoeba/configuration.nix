{ config, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./services.nix
  ];

  system.stateVersion = "26.11";

  networking.hostName = "amoeba";
  networking.domain = "polaris";

  networking.interfaces.eth0 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = config.polaris.hosts.amoeba.public.ipv4;
        prefixLength = 22;
      }
    ];
    ipv6.addresses = [
      {
        address = config.polaris.hosts.amoeba.public.ipv6;
        prefixLength = 64;
      }
    ];
  };
  networking.defaultGateway = {
    address = "152.53.92.1";
    interface = "eth0";
  };
  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "eth0";
  };

  fileSystems =
    let
      common = [
        "compress=zstd"
        "noatime"
      ];
    in
    {
      "/".options = common;
      "/home".options = common;
      "/nix".options = common;
      "/swap".options = [ "noatime" ];
    };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16 * 1024; # 16G
    }
  ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };

  services.qemuGuest.enable = true;
}
