{ config, ... }: {
  services.tailscale = let commonFlags = [
    "--ssh"
    "--advertise-exit-node"
    "--accept-dns=false"
    "--auto-update=false"
  ]; in {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
    disableTaildrop = true;
    extraSetFlags = commonFlags;
    extraUpFlags = commonFlags;
    inherit (config.cfg.secrets.tailscale) authKeyFile;
  };
}