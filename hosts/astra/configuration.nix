{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../oci-arm-base.nix
    ./services.nix
  ];

  system.stateVersion = "25.11";

  networking.hostName = "astra";
  networking.domain = "polaris";

  polaris.remoteBuilder.enable = true;

  boot.binfmt.emulatedSystems = [
    "x86_64-linux"
  ];

  services.hydra-queue-builder-dev.settings.systems = [
    "aarch64-linux"
  ];
  nix.settings = {
    min-free = 8 * 1024 * 1024 * 1024;
    max-free = 16 * 1024 * 1024 * 1024;
    system-features = lib.mkForce [
      "nixos-test"
      "benchmark"
      "big-parallel"
      "gccarch-armv8-a"
      "uid-range"
    ];
  };
}
