{
  inputs,
  legacy01,
  pkgs,
  lib,
  ...
}:
let
  creds = "/run/credentials/@system";
  # garage insists on 0600 secret files, but systemd credentials are 0440,
  # so the secrets get copied into garage's private runtime dir instead
  # (see ExecStartPre below)
  garageSecrets = "/run/garage";
  garageSecretFiles = {
    rpc_secret = "garage_rpc_secret";
    admin_token = "garage_admin_token";
    metrics_token = "garage_metrics_token";
  };
in
{
  imports = [
    inputs.devlootbox.nixosModules.default
  ];

  system.stateVersion = "26.11";

  networking.useHostResolvConf = false;
  networking.nameservers = [
    "1.1.1.1"
    "9.9.9.9"
  ];
  networking.firewall.allowedTCPPorts = [
    legacy01.garage.s3WebPort
    legacy01.garage.adminPort
  ];

  services.postgresql = {
    package = pkgs.postgresql_18;
    enableJIT = true;
  };

  services.devlootbox-bot = {
    enable = true;

    database = {
      setupPostgres = true;
      sqlxMigrations = {
        enable = true;
        # XXX: remove once nixpkgs fixes it (NixOS/nixpkgs#570940)
        # cargoSetupHook now forces system sqlite, but sqlx-cli doesn't have it in buildInputs
        package = pkgs.sqlx-cli.overrideAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.sqlite ];
        });
      };
    };

    aws = {
      region = "garage";
      endpointUrl = "http://127.0.0.1:3900";
      accessKeyIdFile = "${creds}/devlootbox_s3_key_id";
      secretAccessKeyFile = "${creds}/devlootbox_s3_secret";
    };
    discord.tokenFile = "${creds}/devlootbox_discord_token";
    scrapeDoTokenFile = "${creds}/devlootbox_scrape_do_token";

    svc-updater.enable = true;
    svc-media = {
      enable = true;
      settings.s3_bucket = "svc-media";
    };
    svc-discord = {
      enable = true;
      settings.media_cdn_url = "https://media-cdn.devlootbox.on.lunya.cc/";
    };
  };

  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    settings = {
      data_dir = "/data/garage/data";
      metadata_dir = "/data/garage/metadata";
      metadata_snapshots_dir = "/data/garage/snapshots";

      replication_factor = 1;
      consistency_mode = "degraded";

      db_engine = "lmdb";
      compression_level = 1;

      rpc_secret_file = "${garageSecrets}/rpc_secret";
      rpc_bind_addr = "127.0.0.1:3901";

      s3_api = {
        api_bind_addr = "127.0.0.1:3900";
        s3_region = "garage";
        root_domain = ".s3.garage";
      };
      s3_web = {
        bind_addr = "[::]:${toString legacy01.garage.s3WebPort}";
        add_host_to_metrics = true;
        root_domain = ".web.garage";
      };
      admin = {
        api_bind_addr = "[::]:${toString legacy01.garage.adminPort}";
        admin_token_file = "${garageSecrets}/admin_token";
        metrics_token_file = "${garageSecrets}/metrics_token";
        metrics_require_token = true;
      };
    };
  };

  users.groups.garage.gid = legacy01.garage.uid;
  users.users.garage = {
    isSystemUser = true;
    group = "garage";
    uid = legacy01.garage.uid;
  };

  systemd.services.garage.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "garage";
    Group = "garage";
    ReadWritePaths = [ "/data/garage/snapshots" ]; # (upstream only adds data/metadata)
    RuntimeDirectory = "garage";
    RuntimeDirectoryMode = "0700";
    # (services only see their own credentials, so load them first, then copy out of %d as root)
    LoadCredential = lib.mapAttrsToList (file: id: "${file}:${creds}/${id}") garageSecretFiles;
    ExecStartPre = lib.mapAttrsToList (
      file: _:
      "+${pkgs.coreutils}/bin/install -m 0600 -o garage -g garage %d/${file} ${garageSecrets}/${file}"
    ) garageSecretFiles;
  };
}
