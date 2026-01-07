{
  config,
  lib,
  dns,
  ...
}:
let
  cfg = config.polaris.services.dns-server;
in
{
  imports = [
    ./zones/girl_pp_ua.nix
    ./zones/lunya_cc.nix
    ./zones/polaris.nix
  ];

  options.polaris.services.dns-server = {
    enable = lib.mkEnableOption "dns-server";
    loopbackAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.17.53";
    };
    zones = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
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
        cfg.loopbackAddress
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
      zones = lib.mapAttrs (name: cfg: {
        data = dns.lib.toString name cfg;
      }) cfg.zones;
    };
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };
}
