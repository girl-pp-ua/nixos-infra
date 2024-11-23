{ dns, ... }: {
  # services.coredns = {
  #   enable = true;
  # };
  services.nsd = rec {
    enable = true;
    interfaces = [
      "eth0"
      "tailscale0"
    ];
    ipTransparent = true;
    ipFreebind = true;
    serverCount = 2;
    reuseport = serverCount > 1;
    roundRobin = true;
    extraConfig = ''
      server:
        refuse-any: yes
    '';
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