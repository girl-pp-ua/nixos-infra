{ lib, ... }: {
  boot = {
    initrd.kernelModules = [
      "virtio_scsi"
    ];
    kernelParams = [
      "console=tty1"
      "console=ttyS0"
      "nvme.shutdown_timeout=10"
      "libiscsi.debug_libiscsi_eh=1"
      "crash_kexec_post_notifiers"
    ];
  };

  fileSystems = {
    "/boot" = {
      device = lib.mkOverride "/dev/disk/by-label/BOOT";
    };
    "/boot/efi" = {
      device = lib.mkOverride "/dev/disk/by-label/UEFI";
    };
    "/" = {
      device = lib.mkOverride "/dev/disk/by-label/cloudimg-rootfs";
      autoResize = true;
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

  networking.timeServers = [
    "169.254.169.254"
  ];
}