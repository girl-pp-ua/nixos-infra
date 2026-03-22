{ pkgs, ... }:
{
  services.xserver = {
    enable = true;
    videoDrivers = [ "dummy" ];
  };

  services.xserver.displayManager.startx = {
    enable = true;
    generateScript = true;
  };
  services.displayManager.defaultSession = "xfce";

  services.xserver.desktopManager.xfce = {
    enable = true;
    enableScreensaver = false;
  };

  # HACK: probabaly not the most straight-forward way to start a X11 session... but it works
  systemd.services.xrdp-session = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "xrdp.service"
      "xrdp-sesman.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "gamer";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
      ExecStart = "${pkgs.xrdp}/bin/xrdp-sesrun -g 1920x1080";
      RemainAfterExit = true;
    };
  };
}
