{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/cpu.nix
    ./modules/fs_data.nix
    ./modules/fs_root.nix
    ./modules/gpu.nix
    ./modules/tpm2.nix
    ./modules/wifi.nix
    ./services.nix
  ];

  system.stateVersion = "24.11";

  networking.hostName = "astra";
  networking.domain = "polaris";

  # reduce swappiness
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };
}
