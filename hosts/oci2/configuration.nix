{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ../oci-amd-base/configuration.nix
  ];

  networking.hostName = "secondary-vnic";
}