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
      timeout = 0;
    };
    tmp = {
      # we got machine with 1gb of ram, so we can't afford to use tmpfs
      useTmpfs = false;
      cleanOnBoot = true;
    };
  };
}