{ lib, pkgs, ... }: {
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "nohibernate" # disable hibernation support
    ];
    initrd = {
      systemd = {
        enable = lib.mkDefault true; # (disabled on lustrated systems)
        strip = true;
      };
      verbose = true;
    };
    loader.timeout = 3; # actually don't set it to 0, the oracle cloud console's too slow to interrupt the boot
    tmp = {
      useTmpfs = lib.mkDefault true; # (disabled on hosts with low amount of ram)
      cleanOnBoot = true;
    };
  };

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
      netbootxyz.enable = true; # (for troubleshooting)
      configurationLimit = 10;
    };
  };

  # boot.loader.efi.canTouchEfiVariables = false;
  # boot.loader.grub = {
  #   efiSupport = true;
  #   efiInstallAsRemovable = true;
  #   device = "nodev";
  # };
}