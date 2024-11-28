{ config, lib, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.tailscale.enable = lib.mkEnableOption "tailscale" // {
      default = true;
    };
  };
  config = lib.mkIf cfg.services.tailscale.enable {
    services.tailscale = let
      commonFlags = [
        "--ssh"
        "--advertise-exit-node"
        "--accept-dns=false"
      ];
    in {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "server";
      disableTaildrop = true;
      extraSetFlags = commonFlags;
      extraUpFlags = commonFlags;
      inherit (cfg.secrets.tailscale) authKeyFile;
    };
  };
}