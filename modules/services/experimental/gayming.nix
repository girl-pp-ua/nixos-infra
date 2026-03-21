{
  config,
  lib,
  secrets,
  ...
}:
let
  cfg = config.polaris.services.experimental.gayming;
  gid = 600;
  uid = 600;
in
{
  options.polaris.services.experimental.gayming = {
    enable = lib.mkEnableOption "gayming";

    dataPath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/steam-headless";
    };

    novncPort = lib.mkOption {
      type = lib.types.port;
      default = 6080;
    };
    sunshineBasePort = lib.mkOption {
      type = lib.types.port;
      default = 47989;
    };
  };
  config = lib.mkIf cfg.enable {
    polaris.services.experimental.docker.enable = true;

    virtualisation.oci-containers.containers.steam-headless = {
      image = "ghcr.io/steam-headless/steam-headless:latest";
      autoStart = true;
      hostname = "steam-headless";

      # ports = [
      #   "${toString cfg.novncPort}:8083"
      #   "${toString cfg.sunshineBasePort}:47989/tcp"
      #   "${toString cfg.sunshineBasePort}:47989/udp"
      #   "${toString (cfg.sunshineBasePort + 9)}:47998/udp"
      #   "${toString (cfg.sunshineBasePort + 10)}:47999/udp"
      #   "${toString (cfg.sunshineBasePort + 11)}:48000/udp"
      #   "${toString (cfg.sunshineBasePort + 13)}:48002/udp"
      #   "${toString (cfg.sunshineBasePort + 21)}:48010/tcp"
      #   "${toString (cfg.sunshineBasePort + 21)}:48010/udp"
      # ];

      networks = [ "host" ];

      devices = [
        "/dev/dri/renderD128"
        # "/dev/dri/card1"
        "/dev/fuse"
      ];

      capabilities = {
        SYS_ADMIN = true;
        SYS_NICE = true;
      };

      volumes = [
        "${cfg.dataPath}/home:/home/default:rw"
        "${cfg.dataPath}/games:/mnt/games:rw"
      ];

      environment = {
        NAME = "SteamHeadless";
        TZ = "Europe/Warsaw";

        MODE = "primary";
        DISPLAY = ":55";

        ENABLE_STEAM = "true";
        # STEAM_ARGS = "-silent -bigpicture";

        WEB_UI_MODE = "vnc";
        ENABLE_VNC_AUDIO = "true";
        PORT_NOVNC_WEB = "8083";

        ENABLE_SUNSHINE = "true";
        SUNSHINE_USER = "sunshine";
        SUNSHINE_PASS = secrets.steam-headless.sunshine_password; # TODO avoid plaintext

        PUID = toString uid;
        PGID = toString gid;
        UMASK = "022";
        USER_PASSWORD = secrets.steam-headless.user_password; # TODO avoid plaintext

        FORCE_X11_DUMMY_CONFIG = "true";
      };

      extraOptions = [
        # "--ipc=host" # not sure this is needed
        "--dns=1.1.1.1"
        "--dns=8.8.8.8"
        "--ulimit=nofile=1024:524288"
        # "--security-opt=seccomp=unconfined"
        # "--security-opt=apparmor=unconfined"
        "--add-host=steam-headless:127.0.0.1"
        "--memory=8g"
      ];
    };

    hardware.uinput.enable = true;
    # services.udev.enable = true;
    # services.udev.extraRules = ''
    #   KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    # '';

    users.users.steam-headless = {
      inherit uid;
      isSystemUser = true;
      group = "steam-headless";
      extraGroups = [
        "audio"
        "video"
        "input"
        "uinput"
      ];
    };
    users.groups.steam-headless = {
      inherit gid;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath}/home 0755 steam-headless steam-headless -"
      "d ${cfg.dataPath}/games 0755 steam-headless steam-headless -"
    ];

    # networking.firewall.interfaces."tailscale0" = {
    #   allowedTCPPorts = [
    #     cfg.novncPort
    #     cfg.sunshineBasePort
    #     (cfg.sunshineBasePort + 21)
    #   ];
    #   allowedUDPPorts = [
    #     cfg.sunshineBasePort
    #     (cfg.sunshineBasePort + 9)
    #     (cfg.sunshineBasePort + 10)
    #     (cfg.sunshineBasePort + 11)
    #     (cfg.sunshineBasePort + 13)
    #     (cfg.sunshineBasePort + 21)
    #   ];
    # };
  };
}
