{ lib, ... }:
{
  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    extraConfig = ''
      [Resolve]
      DNS=${
        lib.concatStringsSep " " [
          "2620:0:ccd::2#sandbox.opendns.com"
          "2620:0:ccc::2#sandbox.opendns.com"
          "2620:fe::10#dns10.quad9.net"
          "2620:fe::fe:10#dns10.quad9.net"

          "208.67.220.2#sandbox.opendns.com"
          "208.67.222.2#sandbox.opendns.com"
          "9.9.9.10#dns10.quad9.net"
          "149.112.112.10#dns10.quad9.net"
        ]
      }
      Domains=~.
    '';
  };

  boot.kernelModules = [ "dummy" ];
  systemd.network.netdevs."10-dummy0" = {
    netdevConfig = {
      Kind = "dummy";
      Name = "dummy0";
    };
  };
  systemd.network.networks."10-dummy0" = {
    matchConfig.Name = "dummy0";
    networkConfig = {
      DNS = "127.0.0.1";
      DNSOverTLS = false;
      DNSSEC = false;
      Domains = [ "~nix-infra" ];
      LinkLocalAddressing = "ipv4";
      DHCP = "no";
    };
    addresses = [
      { Address = "192.0.2.0/24"; }
    ];
  };
}
