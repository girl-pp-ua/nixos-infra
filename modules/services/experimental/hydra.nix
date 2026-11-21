{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.experimental.hydra;
  secrets' = config.security.nix-secrets.secrets;

  # RunCommand hook: push each successful build's outputs to attic
  atticPush = pkgs.writeShellScript "hydra-attic-push" ''
    set -euo pipefail
    [ "$(${lib.getExe pkgs.jq} -r .buildStatus "$HYDRA_JSON")" = 0 ] || exit 0
    umask 077
    XDG_CONFIG_HOME="$(mktemp -d)"
    export XDG_CONFIG_HOME
    trap 'rm -rf "$XDG_CONFIG_HOME"' EXIT
    mkdir "$XDG_CONFIG_HOME/attic"
    cat > "$XDG_CONFIG_HOME/attic/config.toml" <<EOF
    default-server = "cache"
    [servers.cache]
    endpoint = "https://${config.polaris.services.attic.domain}"
    token = "$(${lib.getExe pkgs.gawk} '$1 == "password" { print $2 }' "$CREDENTIALS_DIRECTORY/attic-token")"
    EOF
    ${lib.getExe pkgs.jq} -r '.outputs[].path' "$HYDRA_JSON" \
      | ${lib.getExe pkgs.attic-client} push main --stdin
  '';
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
      hydraURL = "http://localhost:${toString cfg.port}";
      notificationSender = "hydra@localhost";
      useSubstitutes = true;
      evaluatorSettings.max_concurrent_evals = 2;
      extraConfig = ''
        evaluator_max_memory_size = 4096
        evaluator_workers = 8
        max_output_size = ${toString (8 * 1024 * 1024 * 1024)}

        <runcommand>
          job = *:*:*
          command = ${atticPush}
        </runcommand>
      '';
    };

    # private flake submodules (nixos-infra), git only uses each token for its repo
    systemd.services.hydra-evaluator.serviceConfig.EnvironmentFile =
      config.security.nix-secrets.templates."hydra-git.env".path;
    security.nix-secrets.templates."hydra-git.env".content = libx.gitInsteadOfEnv {
      "https://github.com/girl-pp-ua/secrets" = secrets'."ci/github/secrets_token".templateKey;
      "https://github.com/ProjectLootBox/DevLootBox-bot" =
        secrets'."ci/github/devlootbox_token".templateKey;
    };

    # runcommand plugins run inside hydra-notify
    systemd.services.hydra-notify.serviceConfig.LoadCredential = [
      "attic-token:${secrets'."hydra/attic_token".path}"
    ];

    security.nix-secrets.secrets = {
      "ci/github/secrets_token" = { };
      "ci/github/devlootbox_token" = { };
      "hydra/attic_token".generator.attic-token = {
        sub = "hydra";
        pull = [ "main" ];
        push = [ "main" ];
      };
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

          @block path /nix-cache-info /nar/* *.narinfo /build/*/nix/* /build/*/download/* /build/*/output/* /channel/* /*/channel/*
          respond @block 403

          reverse_proxy localhost:${toString cfg.port}
        '';
      };
      "http://${cfg.intraDomain}" = {
        listenAddresses = config.polaris.services.caddy.internalListenAddresses;
        extraConfig = ''
          import encode
          reverse_proxy localhost:${toString cfg.port}
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
