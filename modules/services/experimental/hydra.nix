{
  config,
  system,
  lib,
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
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "hydra.polaris";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "hydra.lunya.cc";
    };
  };
  config = lib.mkIf cfg.enable {
    services.hydra = {
      enable = true;
      inherit (cfg) port;
      listenHost = "localhost";
      hydraURL = "http://localhost:${cfg.port}";
      notificationSender = "hydra@localhost";
      buildMachinesFiles = [
        {
          hostName = "localhost";
          protocol = null;
          inherit system;
          supportedFeatures = [
            "kvm"
            "nixos-test"
            "big-parallel"
            "benchmark"
          ];
          maxJobs = 8;
        }
      ];
      useSubstitutes = true;
    };

    # required for hydra
    nix.settings = {
      keep-derivations = lib.mkForce true;
      keep-outputs = lib.mkForce true;
    };

    services.caddy.virtualHosts."${cfg.intraDomain}" = {
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode
        reverse_proxy localhost:${cfg.port}
      '';
    };
  };
}
