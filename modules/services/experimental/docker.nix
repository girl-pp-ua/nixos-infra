{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.polaris.services.experimental.docker;
in
{
  options.polaris.services.experimental.docker = {
    enable = lib.mkEnableOption "docker";
  };
  config = lib.mkIf cfg.enable {
    virtualisation = {
      containers = {
        enable = true;
        storage.settings.storage.driver = "btrfs";
      };
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        # defaultNetwork.settings.dns_enabled = true;
      };
    };

    # networking.firewall.interfaces.podman0.allowedUDPPorts = [ 53 ];

    # this is not great, but eh
    # networking.firewall = {
    #   trustedInterfaces = [ "podman0" ];
    # };

    users.users.nixos = {
      extraGroups = [
        "podman"
      ];
    };

    # systemd.services.podman-create-pod = {
    #   serviceConfig.Type = "oneshot";
    #   wantedBy = [ "multi-user.target" ];
    #   script = ''
    #     ${pkgs.podman}/bin/podman network exists network || \
    #     ${pkgs.podman}/bin/podman network create --subnet 192.168.69.0/24 network
    #   '';
    # };

  };
}
