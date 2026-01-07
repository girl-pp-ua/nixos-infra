{ config, lib, ... }:
let
  cfg = config.polaris.services.tailscale;
in
{
  options.polaris.services.tailscale = {
    enable = lib.mkEnableOption "tailscale" // {
      default = true;
    };
  };
  config = lib.mkIf cfg.enable {
    services.tailscale =
      let
        commonFlags = [
          "--ssh"
          "--advertise-exit-node"
          "--accept-dns=false"
        ];
      in
      {
        enable = true;
        openFirewall = true;
        useRoutingFeatures = "server";
        disableTaildrop = true;
        extraSetFlags = commonFlags;
        extraUpFlags = commonFlags;
        authKeyFile = config.sops.secrets."tailscale/authKey".path;
      };

    systemd.services.tailscaled.restartIfChanged = false; # just don't.
    # restartIfChanged = !polaris.services.tailscale.isTsDeploy;

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
    };

    sops.secrets."tailscale/authKey" = {
      mode = "0400";
      owner = "root";
      group = "root";
    };
  };
}
