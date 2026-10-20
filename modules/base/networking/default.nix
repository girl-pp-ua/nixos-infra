{ ... }:
{
  imports = [
    ./firewall.nix
    ./dns.nix
  ];
  networking = {
    useNetworkd = true;
    usePredictableInterfaceNames = false;
  };
  systemd.network = {
    enable = true;
    wait-online.enable = false;
  };
  # bbr + fq handle the bufferbloated home uplink much better than cubic + fq_codel
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr"; # (applies to ipv6 too)
    # don't collapse cwnd on idle keepalive connections (e.g. edge to origin)
    "net.ipv4.tcp_slow_start_after_idle" = 0;
  };
  systemd.services = {
    NetworkManager-wait-online.enable = false;
    systemd-networkd.stopIfChanged = false;
  };
}
