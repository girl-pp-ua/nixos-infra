{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../oci-amd-base.nix
    ./services.nix
  ];

  system.stateVersion = "25.05";

  networking.hostName = "oci2";
  networking.domain = "polaris";
}
