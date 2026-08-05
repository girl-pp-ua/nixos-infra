{
  config,
  pkgs,
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

    services.caddy.virtualHosts = {
      "${cfg.domain}" = {
        extraConfig = ''
          import encode
          import norobot

          @block path /nix-cache-info /nar/* *.narinfo /build/*/nix/closure /build/*/nix/closure/* /build/*/download/* /channel/* /*/channel/*
          respond @block 403

          reverse_proxy localhost:${cfg.port}
        '';
      };
      "http://${cfg.intraDomain}" = {
        extraConfig = ''
          import encode
          reverse_proxy localhost:${cfg.port}
        '';
      };
    };

    systemd.services.kick-hydra = {
      script = ''
        ${pkgs.systemd}/bin/systemctl restart hydra-evaluator
        ${pkgs.systemd}/bin/systemctl restart hydra-queue-runner
      '';
      startAt = "0/6:00";
      wantedBy = [ "multi-user.target" ];
    };

  };
}
