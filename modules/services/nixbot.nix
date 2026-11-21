{
  config,
  pkgs,
  lib,
  libx,
  inputs,
  ...
}:
let
  cfg = config.polaris.services.nixbot;
  cfg-svc = config.polaris.services;
  secrets = config.security.nix-secrets.secrets;
  kanidmPersons =
    (lib.findFirst (host: host.config.polaris.services.kanidm.enable) (throw "no host runs kanidm") (
      lib.attrValues inputs.self.nixosConfigurations
    )).config.services.kanidm.provision.persons;
  idp = libx.idp {
    domain = cfg-svc.kanidm.domain;
    inherit (cfg) client_id;
  };
  atticPush = pkgs.writeShellScript "nixbot-attic-push" ''
    set -euo pipefail
    umask 077
    XDG_CONFIG_HOME="$(mktemp -d)"
    export XDG_CONFIG_HOME
    trap 'rm -rf "$XDG_CONFIG_HOME"' EXIT
    mkdir "$XDG_CONFIG_HOME/attic"
    cat > "$XDG_CONFIG_HOME/attic/config.toml" <<EOF
    default-server = "cache"
    [servers.cache]
    endpoint = "https://${cfg-svc.attic.domain}"
    token = "$ATTIC_TOKEN"
    EOF
    ${lib.getExe pkgs.attic-client} push main --stdin
  '';
in
{
  imports = [ inputs.nixbot.nixosModules.nixbot ];

  options.polaris.services.nixbot = {
    enable = lib.mkEnableOption "nixbot CI";
    port = lib.mkOption {
      type = lib.types.port;
      default = 16112;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "ci.lunya.cc";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "nixbot";
    };
    github.appId = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "GitHub App id";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nixbot = {
      enable = true;
      inherit (cfg) domain port;
      useHTTPS = true;
      nginx.enable = false;

      # nixbot matches admins by name only, so expand the kanidm role here
      admins = lib.mapAttrsToList (
        name: _: "oidc:${lib.removePrefix "https://" idp.oidc_issuer_uri}:${name}"
      ) (lib.filterAttrs (_: p: lib.elem "nixbot.admin" p.groups) kanidmPersons);

      buildSystems = [ "x86_64-linux" ];
      evalWorkerCount = 4;
      evalMaxMemorySize = 4096;

      oidc = {
        enable = true;
        name = "Girlcock";
        discoveryUrl = idp.oidc_discovery;
        clientId = cfg.client_id;
        clientSecretFile = secrets."nixbot/clientSecret".path;
        mapping.username = "preferred_username";
      };

      gitea = {
        enable = true;
        instanceUrl = "https://${cfg-svc.forgejo.domain}";
        tokenFile = secrets."nixbot/forgejo_token".path;
        topic = "nixbot";
      };

      github = lib.mkIf (cfg.github.appId != null) {
        enable = true;
        inherit (cfg.github) appId;
        appSecretKeyFile = secrets."nixbot/github/app_key".path;
        webhookSecretFile = secrets."nixbot/github/webhook_secret".path;
        topic = "nixbot";
      };

      uploaders = [
        {
          name = "attic";
          command = [ "${atticPush}" ];
          environment.ATTIC_TOKEN = inputs.nixbot.lib.interpolate "%(secret:attic-token)s";
          pathsVia = "stdin";
        }
      ];
    };

    # upstream binds the port on every interface, caddy is the only client
    systemd.sockets.nixbot.socketConfig.ListenStream = lib.mkForce "127.0.0.1:${toString cfg.port}";
    systemd.services.nixbot.serviceConfig.LoadCredential = [
      "attic-token:${secrets."nixbot/attic_token".path}"
    ];

    security.nix-secrets.secrets = {
      "nixbot/clientSecret" = { };
      "nixbot/forgejo_token" = { };
      "nixbot/attic_token".generator.attic-token = {
        sub = "nixbot";
        pull = [ "main" ];
        push = [ "main" ];
        netrc = false;
      };
    }
    // lib.optionalAttrs (cfg.github.appId != null) {
      "nixbot/github/app_key" = { };
      "nixbot/github/webhook_secret" = { };
    };

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      import norobot
      reverse_proxy localhost:${toString cfg.port} {
        # build logs are streamed over SSE
        flush_interval -1
      }
    '';
  };
}
