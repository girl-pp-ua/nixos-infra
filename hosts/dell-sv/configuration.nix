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
  ];

  system.stateVersion = "24.11";

  # kernel param

  # services
  # services.thermald.enable = true;
  # services.fwupd.enable = true;

  # cpu

  # reduce swappiness
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };
}
