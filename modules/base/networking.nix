{ ... }: {
  imports = [
    ./networking/firewall.nix
  ];
  networking = {
    useNetworkd = true;
    usePredictableInterfaceNames = false;
  };
  systemd.network = {
    enable = true;
    wait-online.enable = false;
  };
  systemd.services = {
    NetworkManager-wait-online.enable = false;
    systemd-networkd.stopIfChanged = false;
    systemd-resolved.stopIfChanged = false;
  };
}