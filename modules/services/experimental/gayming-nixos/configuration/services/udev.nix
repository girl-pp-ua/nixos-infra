{ lib, useVuinputd, ... }:
{
  config = lib.mkIf (!useVuinputd) {
    services.udev.enable = lib.mkForce true;
    systemd.services.systemd-udevd.unitConfig.ConditionPathIsReadWrite = "";
  };
}
