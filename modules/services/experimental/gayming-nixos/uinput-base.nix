{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.polaris.services.experimental.gayming-nixos;
in
{
  config = lib.mkIf cfg.enable {
    hardware.uinput.enable = true;
    services.udev.packages = [
      pkgs.sunshine
    ];
    services.libinput.enable = true;
    systemd.tmpfiles.rules = [
      "d /run/udev 0755 root root -"
      "d /run/udev/data 0755 root root -"
      "f /run/udev/control 0666 root root -"
    ];
  };
}
