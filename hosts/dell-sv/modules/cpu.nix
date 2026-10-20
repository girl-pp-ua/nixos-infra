{ ... }:
{
  hardware.cpu.amd.updateMicrocode = true;
  boot.kernelParams = [
    "amd_pstate=active"
  ];

  # firmware defaults to "quiet", which caps package power and throttles under load
  # (choices: cool quiet balanced performance)
  systemd.services.platform-profile = {
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for _ in $(seq 20); do
        [ -w /sys/firmware/acpi/platform_profile ] && break
        sleep 0.5
      done
      echo balanced > /sys/firmware/acpi/platform_profile
    '';
  };
}
