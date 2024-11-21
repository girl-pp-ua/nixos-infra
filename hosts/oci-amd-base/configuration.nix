# Base configuration for OCI AMD (VM.Standard.E2.1.Micro) instances
# Assumes a NixOS installed with NIXOS_LUSTRATE over the Ubuntu 24.04 image
{ lib, ... }: {
  boot = rec {
    # systemd-in-initrd is not supported by NIXOS_LUSTRATE
    initrd.systemd.enable = lib.mkOverride 99 false;
    initrd.availableKernelModules = [
      "virtio_scsi"
      "ata_piix"
      "uhci_hcd"
      "xen_blkfront"
      # "vmw_pvscsi"
    ];
    initrd.kernelModules = [
      "virtio_scsi"
      "nvme"
    ];
    kernelModules = [
      "kvm-amd"
    ] ++ initrd.kernelModules;
    kernelParams = [
      "console=tty1"
      "console=ttyS0"
      "nvme.shutdown_timeout=10"
      "libiscsi.debug_libiscsi_eh=1"
      "crash_kexec_post_notifiers"
    ];
    loader = {
      efi.efiSysMountPoint = "/boot/efi";
      systemd-boot.graceful = true;
    };
    growPartition = true;
  };

  fileSystems = {
    "/boot" = {
      device = lib.mkOverride 99 "/dev/disk/by-label/BOOT";
    };
    "/boot/efi" = {
      device = lib.mkOverride 99 "/dev/disk/by-label/UEFI";
    };
    "/" = {
      device = lib.mkOverride 99 "/dev/disk/by-label/cloudimg-rootfs";
      autoResize = true;
    };
  };

  # We absolutely *need* to have a swap file
  # (...as the instance only has 1GB of RAM)
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # (16GB)
    }
  ];

  # Oracle Cloud time servers
  networking.timeServers = [
    "169.254.169.254"
  ];
}