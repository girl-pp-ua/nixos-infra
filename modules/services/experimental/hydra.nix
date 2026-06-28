{
  config,
  lib,
  secrets,
  ...
}:
let
  cfg = config.polaris.services.experimental.hydra;
in
{
  options.polaris.services.experimental.hydra = {
    enable = lib.mkEnableOption "hydra";
    port = lib.mkOption {
      type = lib.types.port;
      default = 16109;
    };
  };
  config = lib.mkIf cfg.enable {
    services.hydra = {
      enable = true;
      inherit (cfg) port;
      # listenHost = "localhost";
      listenHost = "*";
      hydraURL = "http://localhost:3000";
      notificationSender = "hydra@localhost";
      useSubstitutes = true;
    };
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };
    # required for hydra
    nix.settings = {
      keep-derivations = lib.mkForce true;
      keep-outputs = lib.mkForce true;
    };
  };
}
