{
  config,
  lib,
  dns,
  ...
}:
let
  cfg = config.nix-infra.svc.dns-server;
in
{
  options.nix-infra.svc.dns-server = {
    enable = lib.mkEnableOption "dns-server";
    zones = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "girl.pp.ua"
        "nix-infra"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    # TODO switch to coredns
    # services.coredns = {
    #   enable = true;
    # };
    services.nsd = rec {
      enable = true;
      interfaces = [
        "127.0.17.53"
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
      zones =
        let
          mkZone = domain: {
            name = domain;
            value = {
              data = dns.lib.toString domain (import ./dns-zones/${domain}.nix { inherit dns; });
            };
          };
        in
        lib.listToAttrs (lib.map mkZone cfg.zones);
    };
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };
}
