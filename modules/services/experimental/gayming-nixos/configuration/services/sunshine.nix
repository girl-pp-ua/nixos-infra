{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.sunshine = {
    enable = true;
    openFirewall = true;
    autoStart = false;
    settings = {
      capture = "wlr";
      gamepad = "xone";
      origin_web_ui_allowed = "pc";
      # external_ip = "100.64.0.2";
      encoder = "amdvce";
      upnp = "disabled";
      address_family = "both";
      system_tray = "disabled";
    };
    applications = {
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin";
      };
      apps =
        let
          setModeClient = ''sh -c "${pkgs.wlr-randr}/bin/wlr-randr --output HEADLESS-1 --custom-mode ''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS}Hz" '';
          setModeStatic = mode: "${pkgs.wlr-randr}/bin/wlr-randr --output HEADLESS-1 --custom-mode ${mode}";
          setModeDefault = setModeStatic "1280x720@60Hz";
        in
        [
          {
            name = "Desktop";
            image-path = "desktop.png";
            prep-cmd = [
              {
                do = setModeClient;
                undo = setModeDefault;
              }
            ];
          }
          {
            name = "Direct";
            image-path = "";
          }
          {
            name = "Steam";
            image-path = "steam.png";
            prep-cmd = [
              {
                do = setModeClient;
                undo = setModeDefault;
              }
              {
                do = "";
                undo = "setsid steam steam://exit";
              }
            ];
            detached = [
              "setsid steam -bigpicture steam://open/bigpicture"
            ];
          }
          {
            name = "QLaunch";
            image-path = "";
            prep-cmd = [
              {
                do = setModeStatic "1920x1080@60Hz";
                undo = setModeDefault;
              }
            ];
            cmd = "eden -f -qlaunch";
          }
        ];

    };
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
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      inherit (config.systemd.user.services.sunshine.serviceConfig) ExecStart;
      KillMode = "mixed";
      TimeoutStopSec = 15;
      LogRateLimitIntervalSec = 30;
      LogRateLimitBurst = 100;
      Restart = "on-failure";
      RestartSec = 2;
      StartLimitIntervalSec = 30;
      StartLimitBurst = 5;
    };
  };
}
