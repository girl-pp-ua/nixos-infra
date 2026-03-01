{ ... }:
{
  environment.etc."crypttab".text = ''
    data-mq5jJku1 UUID=2a7de5c5-2512-4547-a8bd-d73e3534ac1e - tpm2-device=auto,nofail,timeout=30
  '';
  fileSystems."/mnt/data" = {
    device = "/dev/mapper/data-mq5jJku1";
    fsType = "btrfs";
    options = [
      "nofail"
      "x-systemd.requires=dev-mapper-data\\x2dmq5jJku1.device"
    ];
  };
}
