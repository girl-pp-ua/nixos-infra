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
    users.groups.input.gid = 174;
    services.udev.packages = [
      pkgs.sunshine
    ];
  };
}
