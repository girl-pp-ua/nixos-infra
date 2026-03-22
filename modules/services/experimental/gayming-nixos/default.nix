# TODO gayming as nixos container
{
  config,
  pkgs,
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
  };
  config = lib.mkIf cfg.enable {
    boot.enableContainers = true;
    virtualisation.containers.enable = true;

    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-*" ];
      externalInterface = "eth0"; # XXX: this might need to be changed
      enableIPv6 = true;
    };

    hardware.uinput.enable = true;
    # not sure this is needed on host:
    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0666"
    '';
    services.udev.packages = [
      pkgs.sunshine
    ];

    containers.gayming = {
      autoStart = true;
      privateNetwork = true;
      # TODO fix input with privateUsers
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
          # RDP
          (tcp 3389)
          (udp 3389)

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
        "CAP_IPC_LOCK" # allow mlock etc
        "CAP_MKNOD"
        # "CAP_SYS_ADMIN"
      ];
      allowedDevices = [
        {
          node = "/dev/dri/renderD128";
          modifier = "rw";
        }
        {
          node = "/dev/dri/card1";
          modifier = "rw";
        }
        {
          node = "/dev/uinput";
          modifier = "rwm";
        }
        {
          node = "char-input";
          modifier = "rw";
        }
        {
          node = "char-drm";
          modifier = "rw";
        }
        {
          node = "/dev/input";
          modifier = "rw";
        }
      ];
      bindMounts = {
        "/dev/dri" = {
          hostPath = "/dev/dri";
          isReadOnly = false;
        };
        "/dev/uinput" = {
          hostPath = "/dev/uinput";
          isReadOnly = false;
        };
        "/dev/input" = {
          hostPath = "/dev/input";
          isReadOnly = false;
        };
      };
      specialArgs = {
        inherit secrets;
      };
      config =
        { ... }:
        {
          imports = [
            ./configuration.nix
          ];
        };
    };

  };
}
