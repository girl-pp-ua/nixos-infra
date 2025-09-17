{
  config,
  pkgs,
  lib,
  ...
}:
let
  root_dir = "/data/garage";
  data_dir = "${root_dir}/data";
  metadata_dir = "${root_dir}/metadata";
  metadata_snapshots_dir = "${root_dir}/snapshots";
in
{
  options.cfg.services.garage = {
    enable = lib.mkEnableOption "garage object storage server";
  };
  config = lib.mkIf config.cfg.services.garage.enable {
    services.garage = {
      enable = true;
      package = pkgs.garage_2;
      settings = {
        inherit data_dir metadata_dir metadata_snapshots_dir;

        replication_factor = 1;
        consistency_mode = "degraded";

        db_engine = "lmdb";
        compression_level = 1;
        # metadata_fsync = true;
        # data_fsync = false;

        rpc_secret_file = config.sops.secrets."garage/rpc_secret".path;
        rpc_bind_addr = "[::]:3901";
        rpc_bind_outgoing = true;

        s3_api = {
          api_bind_addr = "[::]:3900";
          s3_region = "garage";
          root_domain = ".s3.garage";
        };
        s3_web = {
          bind_addr = "[::]:3902";
          add_host_to_metrics = true;
          root_domain = ".web.garage";
        };

        admin = {
          api_bind_addr = "127.0.0.1:3903";
          admin_token_file = config.sops.secrets."garage/admin_token".path;
          metrics_token_file = config.sops.secrets."garage/metrics_token".path;
          metrics_require_token = true;
        };
      };
    };

    users.groups.garage = { };
    users.users.garage = {
      isSystemUser = true;
      group = "garage";
      description = "garage";
    };

    systemd.services.garage.serviceConfig = {
      DynamicUser = false;
      User = "garage";
      Group = "garage";
    };

    systemd.tmpfiles.rules = [
      "d ${root_dir} 0750 garage garage -"
      "d ${data_dir} 0750 garage garage -"
      "d ${metadata_dir} 0750 garage garage -"
      "d ${metadata_snapshots_dir} 0750 garage garage -"
    ];

    sops.secrets =
      let
        usr = {
          mode = "0400";
          owner = "garage";
          group = "garage";
        };
      in
      {
        "garage/rpc_secret" = usr;
        "garage/admin_token" = usr;
        "garage/metrics_token" = usr;
      };
  };
}
