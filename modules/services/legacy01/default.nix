# legacy01: isolated nixos-container for legacy side projects (devlootbox + its postgres + garage)
#
# state lives on the host in ${stateDir} and is bind-mounted into the container,
# secrets are decrypted by sops on the host and handed to the container as nspawn credentials
{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.polaris.services.legacy01;
  name = "legacy01";
  inherit (cfg) stateDir;

  # host secret -> container credential id (available at /run/credentials/@system/<id> inside)
  credentials = {
    garage_rpc_secret = "garage/rpc_secret";
    garage_admin_token = "garage/admin_token";
    garage_metrics_token = "garage/metrics_token";
    devlootbox_s3_key_id = "garage/keys/devlootbox/key_id";
    devlootbox_s3_secret = "garage/keys/devlootbox/secret";
    devlootbox_discord_token = "discord/devlootbox/production";
    devlootbox_scrape_do_token = "scrape_do_token";
  };
in
{
  options.polaris.services.legacy01 = {
    enable = lib.mkEnableOption "legacy01 container";
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${name}";
    };
    externalInterface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
    };
    hostAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.101.1";
    };
    localAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.101.2";
    };
    garage = {
      s3WebPort = lib.mkOption {
        type = lib.types.port;
        default = 3902;
      };
      adminPort = lib.mkOption {
        type = lib.types.port;
        default = 3903;
      };
      # pinned so the migrated data dir ownership matches
      uid = lib.mkOption {
        type = lib.types.int;
        default = 900;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.enableContainers = true;

    containers.${name} = {
      autoStart = true;
      privateNetwork = true;
      inherit (cfg) hostAddress localAddress;

      bindMounts = {
        "/var/lib/postgresql" = {
          hostPath = "${stateDir}/postgresql";
          isReadOnly = false;
        };
        "/data/garage" = {
          hostPath = "${stateDir}/garage";
          isReadOnly = false;
        };
        "/var/lib/devlootbox" = {
          hostPath = "${stateDir}/devlootbox";
          isReadOnly = false;
        };
      };

      extraFlags = lib.mapAttrsToList (
        id: secret: "--load-credential=${id}:${config.sops.secrets.${secret}.path}"
      ) credentials;

      specialArgs = {
        inherit inputs;
        legacy01 = cfg;
      };
      config = ./container.nix;
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 root root -"
      "d ${stateDir}/postgresql 0750 71 71 -" # postgres uid/gid are static (71)
      "d ${stateDir}/garage 0750 ${toString cfg.garage.uid} ${toString cfg.garage.uid} -"
      "d ${stateDir}/devlootbox 0755 root root -" # chowned by systemd StateDirectory= in the container
    ];

    # outbound internet for the container
    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-${name}" ];
      inherit (cfg) externalInterface;
    };

    sops.secrets = lib.mapAttrs' (
      _: secret:
      lib.nameValuePair secret {
        restartUnits = [ "container@${name}.service" ];
      }
    ) credentials;

    services.caddy.virtualHosts."media-cdn.devlootbox.on.lunya.cc".extraConfig = ''
      import encode
      import norobot
      reverse_proxy ${cfg.localAddress}:${toString cfg.garage.s3WebPort} {
        header_up Host "svc-media.web.garage"
      }
    '';

    # expose only garage metrics (not the rest of the admin api) for scraping
    services.caddy.virtualHosts."http://:${toString cfg.garage.adminPort}" = {
      extraConfig = ''
        handle /metrics {
          reverse_proxy ${cfg.localAddress}:${toString cfg.garage.adminPort}
        }
        respond 404
      '';
    };
    polaris.services.monitoring.exports.garage = {
      port = cfg.garage.adminPort;
      bearerTokenSecret = "garage/metrics_token";
    };
  };
}
