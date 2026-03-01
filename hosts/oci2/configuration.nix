{ ... }:
{
  system.stateVersion = "25.05";

  imports = [
    ./hardware-configuration.nix
    ../../modules/host_shared/oci-amd-base.nix
  ];
}
