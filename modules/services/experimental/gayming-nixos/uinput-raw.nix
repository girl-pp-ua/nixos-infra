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
  config = lib.mkIf (cfg.enable && !cfg.vuinputd.enable) {
    boot.kernelModules = [
      "uhid"
      "uinput"
      "hid_playstation"
    ];
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "libvirtualhid-udev-rules";
        destination = "/etc/udev/rules.d/60-libvirtualhid.rules";
        text = ''
          KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660", TAG+="uaccess"
          KERNEL=="uhid", GROUP="input", MODE="0660", TAG+="uaccess"

          SUBSYSTEM=="hidraw", KERNEL=="hidraw*", IMPORT{parent}="HID_*"
          SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ENV{HID_PHYS}=="libvirtualhid/uhid/*", GROUP="input", MODE="0660", TAG+="uaccess"
          SUBSYSTEM=="input", KERNEL=="event*", ATTRS{phys}=="libvirtualhid/uhid/*", GROUP="input", MODE="0660", TAG+="uaccess"
        '';
      })
    ];
  };
}
