{ config, lib, dns, ... }:
let cfg = config.cfg; in {
  options = {
    cfg.services.dns-server.enable = lib.mkEnableOption "dns-server";
  };
  config = lib.mkIf cfg.services.dns-server.enable {
    # TODO switch to coredns
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
      serverCount = 1;
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
              (import ./../../../dns-zones/${domain}.nix { inherit dns; });
          };
        };
      in {}
        // mkZone "girl.pp.ua";
    };
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };

}