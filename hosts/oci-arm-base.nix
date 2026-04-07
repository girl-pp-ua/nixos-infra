# Base configuration for OCI AMD (VM.Standard.E2.1.Micro) instances
# Assumes a NixOS installed with NIXOS_LUSTRATE over the Ubuntu 24.04 image
{ lib, ... }:
{
  boot = {
    initrd.systemd.enable = lib.mkOverride 99 false;
    kernelParams = [
      "console=tty1"
      "console=ttyAMA0"
      "nvme.shutdown_timeout=10"
      "libiscsi.debug_libiscsi_eh=1"
      "crash_kexec_post_notifiers"
      "iscsi_auto_skip_initramfs_networking"
    ];
    growPartition = true;
    loader.efi.efiSysMountPoint = "/boot/efi";
    loader.systemd-boot.configurationLimit = lib.mkForce 5;
    # loader.systemd-boot.xbootldrMountPoint = "/boot";
  };

  # Oracle Cloud time servers
  networking.timeServers = [
    "169.254.169.254"
  ];

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
}
