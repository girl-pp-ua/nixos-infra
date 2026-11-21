{
  config,
  pkgs,
  lib,
  libx,
  inputs,
  ...
}:
let
  cfg = config.polaris.services.hydra;
  secrets' = config.security.nix-secrets.secrets;
  hostName = config.networking.hostName;

  # machines running hydra-queue-builder-dev
  builders = {
    amoeba = {
      maxJobs = 8;
      speedFactor = 20;
    };
    astra = {
      maxJobs = 8;
      speedFactor = 10;
    };
    dell-sv = {
      maxJobs = 4;
      speedFactor = 10;
    };
  };

  hydraHost = lib.findFirst (
    name: inputs.self.nixosConfigurations.${name}.config.polaris.services.hydra.enable
  ) null (lib.attrNames inputs.self.nixosConfigurations);

  grpcPort = 16113;
  restPort = 16114;
  wsPort = 16115;

  # the runner reads every builder's token, each builder only its own; both run as group hydra
  builderToken = name: {
    "hydra/builders/${name}" = {
      generator.alphanumeric.length = 64;
      mode = "0440";
      group = "hydra";
    };
  };

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
  imports = [ inputs.hydra.nixosModules.hydra ];

  options.polaris.services.hydra = {
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

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.hydra-dev = {
        enable = true;
        inherit (cfg) port;
        listenHost = "127.0.0.1";
        hydraURL = "https://${cfg.domain}";
        notificationSender = "hydra@localhost";
        useSubstitutes = true;
        extraConfig = ''
          max_output_size = ${toString (8 * 1024 * 1024 * 1024)}
          ws_endpoint = wss://${cfg.domain}/ws

          <runcommand>
            job = *:*:*
            command = ${atticPush}
          </runcommand>
        '';
      };
      services.postgresql.enable = true;

      systemd.services.hydra-init = {
        after = [ "postgresql.target" ];
        requires = [ "postgresql.target" ];
      };

      services.hydra-evaluator-dev.settings = {
        evaluator_workers = 8;
        evaluator_max_memory_size = 4096;
        max_concurrent_evals = 2;
      };

      services.hydra-queue-runner-dev = {
        enable = true;
        grpc = {
          address = "[::]";
          port = grpcPort;
        };
        rest.port = restPort;
        settings.tokenPaths = map (name: secrets'."hydra/builders/${name}".path) (lib.attrNames builders);
      };
      # only builders on the tailnet, and they still need a token
      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
        grpcPort
      ];

      services.hydra-ws-dev = {
        enable = true;
        bind.port = wsPort;
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
      }
      // lib.concatMapAttrs (name: _: builderToken name) builders;

      # base/nix.nix turns these off, hydra needs them
      nix.settings.keep-derivations = lib.mkForce true;
      nix.settings.keep-outputs = lib.mkForce true;
      nix.settings.allowed-uris = [
        "https:"
        "git+https:"
        "git+ssh:"
        "github:"
        "gitlab:"
        "sourcehut:"
      ];

      services.caddy.virtualHosts = {
        "${cfg.domain}" = {
          extraConfig = ''
            import encode
            import norobot

            @block path /nix-cache-info /nar/* *.narinfo /build/*/nix/* /build/*/download/* /build/*/output/* /channel/* /*/channel/*
            respond @block 403

            handle_path /ws* {
              reverse_proxy [::1]:${toString wsPort}
            }
            reverse_proxy 127.0.0.1:${toString cfg.port}
          '';
        };
        "http://${cfg.intraDomain}" = {
          listenAddresses = config.polaris.services.caddy.internalListenAddresses;
          extraConfig = ''
            import encode
            reverse_proxy 127.0.0.1:${toString cfg.port}
          '';
        };
      };

      systemd.services.kick-hydra = {
        script = ''
          ${pkgs.systemd}/bin/systemctl restart hydra-evaluator
          ${pkgs.systemd}/bin/systemctl restart hydra-queue-runner-dev
        '';
        startAt = "0/6:00";
        wantedBy = [ "multi-user.target" ];
      };
    })

    (lib.mkIf (hydraHost != null && builders ? ${hostName}) {
      services.hydra-queue-builder-dev = {
        enable = true;
        queueRunnerAddr = "http://${config.polaris.hosts.${hydraHost}.internal.fqdn}:${toString grpcPort}";
        authorizationFile = secrets'."hydra/builders/${hostName}".path;
        settings = {
          inherit (builders.${hostName}) maxJobs speedFactor;
        };
      };
      security.nix-secrets.secrets = builderToken hostName;
    })
  ];
}
