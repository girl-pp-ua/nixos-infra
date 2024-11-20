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

    # actually don't set it to 0, the oracle cloud console's too slow to interrupt the boot
    loader.timeout = 3;

    # we got machine with 1gb of ram, so we can't afford to use tmpfs
    tmp = {
      useTmpfs = false;
      cleanOnBoot = true;
    };
  };

  # boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.systemd-boot = {
  #   enable = true;
  #   netbootxyz.enable = true;
  # };

  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
}