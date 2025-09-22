{ ... }:
{
  services.resolved = {
    enable = true;
    dnssec = "false";
    dnsovertls = "false";
    extraConfig = ''
      [Resolve]
      DNS=208.67.220.2 208.67.222.2 9.9.9.10 149.112.112.10
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
      Domains = [ "~nix-infra" ];
      LinkLocalAddressing = "ipv4";
      DHCP = "no";
    };
    addresses = [
      { Address = "192.0.2.0/24"; }
    ];
  };
}
