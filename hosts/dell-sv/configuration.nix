{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/bluetooth.nix
    ./modules/cpu.nix
    ./modules/fs_data.nix
    ./modules/fs_root.nix
    ./modules/gpu.nix
    ./modules/tpm2.nix
    ./modules/wifi.nix
    ./services.nix
  ];

  system.stateVersion = "24.11";

  networking.hostName = "dell-sv";
  networking.domain = "polaris";

  # reduce swappiness
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };

  # shared by nextcloud, immich, paperless, forgejo; defaults are tuned for tiny machines
  services.postgresql.settings = {
    shared_buffers = "1GB";
    effective_cache_size = "8GB";
    work_mem = "16MB";
    maintenance_work_mem = "256MB";
    # nvme
    random_page_cost = 1.1;
    effective_io_concurrency = 200;
    # slow query visibility
    shared_preload_libraries = [ "pg_stat_statements" ];
    track_io_timing = true;
    log_min_duration_statement = 500;
  };
}
