{ pkgs, ... }: {
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd = {
      systemd = {
        enable = true;
        strip = true;
      };
      verbose = true;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      # actually don't set it to 0, the oracle cloud console's too slow to interrupt the boot
      timeout = 3;
    };
    tmp = {
      # we got machine with 1gb of ram, so we can't afford to use tmpfs
      useTmpfs = false;
      cleanOnBoot = true;
    };
  };
}