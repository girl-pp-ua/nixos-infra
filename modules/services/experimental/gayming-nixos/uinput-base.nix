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
    users.groups.input.gid = 174;
    users.groups.uinput.gid = 173;
    services.udev.packages = [
      pkgs.sunshine
    ];
  };
}
