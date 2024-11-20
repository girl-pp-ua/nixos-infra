{ ... }: {
  networking = {
    hostName = "oci2"; # todo unhardcode
    useNetworkd = true;
    usePredictableInterfaceNames = false;
    firewall = {
      enable = true; # enable firewall
      filterForward = true;
      allowedTCPPorts = [ 22 ]; # just in case
    };
    nftables = {
      enable = true; # enable nftables
    };
  };
  systemd.network = {
    enable = true;
    # todo: configure
  };
}