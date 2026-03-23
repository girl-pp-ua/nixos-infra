{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.polaris.services.experimental.gayming-nixos;
  vuinputd = pkgs.callPackage ./packages/vuinputd.nix { };
in
{
  config = lib.mkIf (cfg.enable && cfg.vuinputd.enable) {
    services.udev.packages = [
      vuinputd
    ];

    environment.systemPackages = [ vuinputd ];

    systemd.services.vuinputd = {
      description = "uinput proxy";
      wantedBy = [
        "multi-user.target"
        "container@gayming.service"
      ];
      after = [ "systemd-udevd.service" ];
      wants = [ "systemd-udevd.service" ];
      serviceConfig = {
        ExecStart = "${vuinputd}/bin/vuinputd --major 120 --minor 414795";
        Restart = "on-failure";
        # TODO: granular device permissions
        User = "root";
        Group = "root";
        Environment = "RUST_LOG=debug";
      };
    };

    systemd.services.vuinputd-vt-guard = {
      description = "uinput vt guard";
      wantedBy = [ "multi-user.target" ];
      after = [
        "systemd-udevd.service"
        "vuinputd.service"
      ];
      wants = [ "systemd-udevd.service" ];
      serviceConfig = {
        User = "root";
        Group = "root";
        ExecStart = "${vuinputd}/bin/vuinputd --vt-guard";
        RemainAfterExit = true;
        Environment = "RUST_LOG=debug";
      };
    };
  };
}
