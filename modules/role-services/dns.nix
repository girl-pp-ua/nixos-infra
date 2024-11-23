{ dns, ... }: {
  # services.coredns = {
  #   enable = true;
  # };
  services.nsd = {
    enable = true;
    interfaces = [
      "eth0"
      "tailscale0"
    ];
    ipTransparent = true;
    ipFreebind = true;
    reuseport = false;
    zones = let
      mkZone = domain: {
        ${domain} = {
          data = dns.lib.toString domain
            (import ./../../dns-zones/${domain}.nix { inherit dns; });
        };
      };
    in {}
      // mkZone "girl.pp.ua";
  };
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
}