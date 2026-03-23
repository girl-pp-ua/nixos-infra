{ pkgs, lib, ... }:
{
  services.sunshine = {
    enable = true;
    openFirewall = true;
    autoStart = false;
  };

  systemd.services.sunshine = {
    description = "Sunshine";
    wantedBy = [ "default.target" ];
    after = [
      "basic.target"
      "labwc-headless.service"
    ];
    requires = [ "labwc-headless.service" ];
    environment = {
      WAYLAND_DISPLAY = "wayland-0";
      DISPLAY = ":0";
      XDG_RUNTIME_DIR = "/run/user/1000";
      PATH = lib.mkForce "/run/current-system/sw/bin:/usr/bin:/bin";
    };
    serviceConfig = {
      # do we run it as user?
      User = "gamer";
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
      ExecStart = "${pkgs.sunshine}/bin/sunshine";
      KillMode = "mixed";
      TimeoutStopSec = 15;
      LogRateLimitIntervalSec = 30;
      LogRateLimitBurst = 100;
    };
  };
}
