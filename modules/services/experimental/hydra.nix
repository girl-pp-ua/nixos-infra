{
  config,
  system,
  lib,
  inputs,
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

    nix.distributedBuilds = true;
    nix.buildMachines = [
      {
        hostName = "localhost";
        protocol = null;
        inherit system;
        supportedFeatures = [
          "kvm"
          "nixos-test"
          "benchmark"
        ];
        maxJobs = 8;
        speedFactor = 2;
      }
      {
        inherit (secrets.exarch.builder) hostName;
        protocol = "ssh-ng";
        system = "x86_64-linux";
        supportedFeatures = [
          "kvm"
          "big-parallel"
        ];
        speedFactor = 20;
        sshUser = "luna";
        sshKey = config.sops.secrets."keys/exarch".path;
        maxJobs = 16;
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

    sops.secrets = {
      "keys/exarch" = {
        sopsFile = "${inputs.secrets}/keys/exarch.sops";
        format = "binary";
      };
    };
  };
}
