{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../oci-arm-base.nix
  ];

  system.stateVersion = "25.11";

  boot.binfmt.emulatedSystems = [
    "x86_64-linux"
  ];
}
