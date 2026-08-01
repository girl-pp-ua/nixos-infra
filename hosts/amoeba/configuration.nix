{ ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./services.nix
  ];

  system.stateVersion = "26.11";

  networking.hostName = "amoeba";
  networking.domain = "polaris";

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
