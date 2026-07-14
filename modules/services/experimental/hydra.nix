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
      useSubstitutes = true;
      extraConfig = ''
        evaluator_max_memory_size = 4096
        evaluator_workers = 8
        max_concurrent_evals = 2
        max_output_size = ${toString (8 * 1024 * 1024 * 1024)}
      '';
    };

    # nix.distributedBuilds = true;
    nix.buildMachines = [
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
    nix.settings = {
      # keep-{derivations,outputs} is required for hydra
      keep-derivations = lib.mkForce true;
      keep-outputs = lib.mkForce true;
      allowed-uris = [
        "https:"
        "git+https:"
        "git+ssh:"
        "github:"
        "gitlab:"
        "sourcehut:"
      ];
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
