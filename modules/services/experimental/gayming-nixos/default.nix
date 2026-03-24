# TODO gayming as nixos container
{
  config,
  lib,
  secrets,
  ...
}:
let
  cfg = config.polaris.services.experimental.gayming-nixos;
in
{
  options.polaris.services.experimental.gayming-nixos = {
    enable = lib.mkEnableOption "gayming-nixos";
    vuinputd.enable = lib.mkEnableOption "vuinputd" // {
      description = "Use vuinputd for virtual input devices instead of exposing /dev/uinput directly";
    };
  };
  imports = [
    ./uinput-vuinputd.nix
    ./uinput-base.nix
  ];
  config = lib.mkIf cfg.enable {
    polaris.services.backup.extraExclude = [
      "/var/lib/nixos-containers/gayming"
    ];

    boot.enableContainers = true;
    virtualisation.containers.enable = true;

    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-*" ];
      externalInterface = "eth0"; # XXX: this might need to be changed
      enableIPv6 = true;
    };

    containers.gayming = {
      autoStart = true;
      privateNetwork = true;
      # TODO fix input with privateUsers?
      # privateUsers = "pick";
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      hostAddress6 = "fc00::1";
      localAddress6 = "fc00::2";
      # Boot up full system (i.e. invoke init)
      # extraFlags = [ "--boot" ];
      # extraFlags = [ "--privileged" ];
      forwardPorts =
        let
          forward = protocol: port: {
            containerPort = port;
            hostPort = port;
            inherit protocol;
          };
          tcp = forward "tcp";
          udp = forward "udp";
        in
        [
          # Sunshine
          # 47984-47990/tcp
          (tcp 47984)
          (tcp 47985)
          (tcp 47986)
          (tcp 47987)
          (tcp 47988)
          (tcp 47989)
          (tcp 47990)
          # 48010:48010
          (tcp 48010)
          (udp 48010)
          # 47998-48000/udp
          (udp 47998)
          (udp 47999)
          (udp 48000)

          # Steam
          # peer discovery
          (udp 27036)
          # remote play
          (tcp 27036)
          (tcp 27037)
          (udp 10400)
          (udp 10401)
          (udp 27031)
          (udp 27032)
          (udp 27033)
          (udp 27034)
          (udp 27035)
        ];
      additionalCapabilities = [
        "CAP_SYS_NICE"
      ];
      allowedDevices = [
        {
          node = "/dev/dri/renderD128";
          modifier = "rw";
        }
        {
          node = "char-drm";
          modifier = "rw";
        }
        {
          node = "char-input";
          modifier = "rw";
        }
        {
          node = if cfg.vuinputd.enable then "/dev/vuinput" else "/dev/uinput";
          modifier = "rw";
        }
      ];
      bindMounts = {
        "/dev/dri" = {
          hostPath = "/dev/dri";
          isReadOnly = false;
        };
        "/dev/uinput" = {
          hostPath = if cfg.vuinputd.enable then "/dev/vuinput" else "/dev/uinput";
          isReadOnly = false;
        };
        "/dev/input" = {
          hostPath = "/dev/input"; # TODO check if needed
          isReadOnly = false;
        };
      };
      tmpfs = [
        "/dev/shm"
      ];
      specialArgs = {
        inherit secrets;
      };
      config =
        { ... }:
        {
          imports = [
            ./configuration
          ];
        };
    };

  };
}
