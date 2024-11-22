{ config, ... }: {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    inherit (config.cfg.secrets.tailscale) authKeyFile;
  };
}