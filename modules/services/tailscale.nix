{ config, lib, ... }:
let
  inherit (config) cfg;
in
{
  options = {
    cfg.services.tailscale = {
      enable = lib.mkEnableOption "tailscale" // {
        default = true;
      };
      # isTsDeploy = lib.mkEnableOption "tailscale is host intranet" // {
      #   description = "If true, the tailscaled is required for ssh connection and won't be restarted";
      # };
    };
  };
  config = lib.mkIf cfg.services.tailscale.enable {
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
    # restartIfChanged = !cfg.services.tailscale.isTsDeploy;

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
