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

  hosts = inputs.self.nixosConfigurations;
  hydraHost = lib.findFirst (name: hosts.${name}.config.polaris.services.hydra.enable) null (
    lib.attrNames hosts
  );
  builderHosts = lib.filter (name: hosts.${name}.config.polaris.services.hydra.builder.enable) (
    lib.attrNames hosts
  );

  # local clone with bumped inputs
  flakeUpdateDir = "/var/lib/hydra-flake-update";
  flakeUpdateInputs = lib.subtractLists [ "secrets" "devlootbox" ] (
    lib.attrNames (lib.importJSON "${inputs.self}/flake.lock").nodes.root.inputs
  );

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
    # hydra-notify runs with an empty PATH
    PATH=${lib.makeBinPath [ pkgs.coreutils ]}
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
    # dials in to the queue runner over tailscale
    builder = {
      enable = lib.mkEnableOption "hydra builder";
      maxJobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
      };
      speedFactor = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
      };
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
          queue_runner_endpoint = http://[::1]:${toString restPort}

          <runcommand>
            job = *:*:*
            command = ${atticPush}
          </runcommand>
        '';
      };
      services.postgresql.enable = true;
      polaris.services.oauth2_proxy.enable = true;

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
        settings = {
          tokenPaths = map (name: secrets'."hydra/builders/${name}".path) builderHosts;
          # fetch anything already in a cache instead of dispatching it as a build step
          useSubstitutes = true;
        };
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

      systemd.services.hydra-flake-update = {
        description = "Bump nixos-infra inputs for the flake-update jobset";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [
          pkgs.git
          config.nix.package
        ];
        environment.HOME = flakeUpdateDir;
        serviceConfig = {
          Type = "oneshot";
          User = "hydra";
          Group = "hydra";
          StateDirectory = "hydra-flake-update";
          StateDirectoryMode = "0750";
          # private submodules
          EnvironmentFile = config.security.nix-secrets.templates."hydra-git.env".path;
        };
        script = ''
          repo=${flakeUpdateDir}/nixos-infra
          [ -d "$repo/.git" ] || git clone --quiet https://github.com/girl-pp-ua/nixos-infra "$repo"
          cd "$repo"
          git fetch --quiet origin master
          git checkout --quiet --force -B auto FETCH_HEAD
          git submodule --quiet update --init --recursive
          nix --extra-experimental-features "nix-command flakes" flake update ${lib.escapeShellArgs flakeUpdateInputs}
          git add flake.lock
          git -c user.name=hydra -c user.email=hydra@localhost commit --quiet -m "flake.lock: weekly update" || true
        '';
        startAt = "weekly";
      };
      systemd.timers.hydra-flake-update.timerConfig.Persistent = true;

      systemd.tmpfiles.rules = lib.mkBefore [
        "d /var/lib/hydra/runcommand-logs 0750 hydra-queue-runner hydra -"
      ];

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
      // lib.mergeAttrsList (map builderToken builderHosts);

      # base/nix.nix turns these off, hydra needs them
      nix.settings.keep-derivations = lib.mkForce true;
      nix.settings.keep-outputs = lib.mkForce true;
      nix.settings.allowed-uris = [
        "git+file://${flakeUpdateDir}/"
        "file://${flakeUpdateDir}/"
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

            import oauth2_proxy_handle

            @downloads path_regexp hydra_downloads ^/(nix-cache-info|nar/.*|[0-9a-z]{32}\.narinfo|build/[0-9]+/(download|download-by-type|nix|output|contents|reproduce)(/.*)?|(.*/)?channel(/.*)?)$
            handle @downloads {
              import oauth2_proxy_secure_external "hydra_downloads"
              reverse_proxy 127.0.0.1:${toString cfg.port}
            }

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
    })

    (lib.mkIf (hydraHost != null && cfg.builder.enable) {
      services.hydra-queue-builder-dev = {
        enable = true;
        queueRunnerAddr = "http://${config.polaris.hosts.${hydraHost}.internal.fqdn}:${toString grpcPort}";
        authorizationFile = secrets'."hydra/builders/${hostName}".path;
        settings = {
          inherit (cfg.builder) maxJobs speedFactor;
        };
      };
      security.nix-secrets.secrets = builderToken hostName;
    })
  ];
}
