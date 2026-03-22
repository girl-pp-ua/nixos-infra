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

  # systemd.services.xorg-session = {
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "systemd-udev-settle.service" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     Restart = "on-failure";
  #     RestartSec = 3;
  #     ExecStart = "${pkgs.xorg-server}/bin/Xorg :0 vt1 -nolisten tcp -auth /home/gamer/.Xauthority";
  #   };
  # };

  # systemd.user.services.xfce-session = {
  #   wantedBy = [ "default.target" ];
  #   after = [ "xorg-session.service" ];
  #   environment = {
  #     DISPLAY = ":0";
  #     XAUTHORITY = "/home/gamer/.Xauthority";
  #   };
  #   serviceConfig = {
  #     Type = "simple";
  #     Restart = "on-failure";
  #     ExecStart = "${pkgs.xfce4-session}/bin/xfce4-session";
  #   };
  # };

  # systemd.user.services.sunshine = {
  #   wantedBy = [ "default.target" ];
  #   after = [ "xorg-session.service" ];
  #   environment = {
  #     DISPLAY = ":0";
  #     XAUTHORITY = "/home/gamer/.Xauthority";
  #   };
  # };

}
