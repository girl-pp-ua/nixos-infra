{ ... }:
{
  # TODO find better way to handle this shit
  # dummy interface?

  networking.resolvconf.enable = false;
  services.resolved = {
    enable = true;
    dnssec = "false";
    dnsovertls = "false";
    extraConfig = ''
      [Resolve]
      DNS=127.0.0.1#53
      Domains=~nix-infra
      FallbackDNS=208.67.220.2 208.67.222.2 9.9.9.10 149.112.112.10
    '';
  };

  systemd.network.networks."10-main-dns" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      Domains = [ "~." ];
      DNS = [
        # OpenDNS Sandbox
        "2620:0:ccd::2"
        "2620:0:ccc::2"
        "208.67.220.2"
        "208.67.222.2"

        # Quad9 (dns10.quad9.net)
        "2620:fe::10"
        "2620:fe::fe:10"
        "9.9.9.10"
        "149.112.112.10"
      ];
    };
  };
}
