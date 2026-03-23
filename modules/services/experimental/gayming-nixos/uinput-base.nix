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
  };
}
