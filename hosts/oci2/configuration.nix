{ ... }:
{
  system.stateVersion = "25.05";

  imports = [
    ./hardware-configuration.nix
    ../oci-amd-base/configuration.nix
  ];
}
