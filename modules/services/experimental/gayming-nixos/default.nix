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
    containers.gayming = {
      autoStart = true;
      privateNetwork = true;
      privateUsers = "pick";
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      hostAddress6 = "fc00::1";
      localAddress6 = "fc00::2";
      forwardPorts = [
        {
          containerPort = 3389;
          hostPort = 3389;
          protocol = "tcp";
        }
        {
          containerPort = 3389;
          hostPort = 3389;
          protocol = "udp";
        }
      ];
      additionalCapabilities = [
        "CAP_SYS_NICE"
      ];
      allowedDevices = [
        {
          node = "/dev/dri/renderD128";
          modifier = "rwm";
        }
      ];
      bindMounts = {
        "/dev/dri" = {
          hostPath = "/dev/dri";
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
