{ config, lib, ... }:
{
  networking.resolvconf.enable = true;
  services.resolved.enable = false;
  services.unbound = {
    enable = true;
    resolveLocalQueries = true;
    localControlSocketPath = "/run/unbound/unbound.ctl";
    settings = {
      server = {
        so-reuseport = false;
        domain-insecure = [ "polaris" ];
        private-domain = [ "polaris" ];
        do-not-query-localhost = false;
        prefetch = true;
        serve-expired = true;
        serve-expired-ttl = 86400;
        serve-expired-client-timeout = 1800;
      };
      stub-zone = [
        {
          name = "polaris.";
          stub-addr = [
            config.polaris.services.dns-server.loopbackAddress
          ];
          stub-no-cache = true;
          stub-prime = false;
        }
      ]
      ++ lib.optionals config.polaris.services.dns-server.enable (
        map (name: {
          name = "${name}.";
          stub-addr = [ config.polaris.services.dns-server.loopbackAddress ];
          stub-prime = false;
        }) (lib.attrNames (removeAttrs config.polaris.services.dns-server.zones [ "polaris" ]))
      );
      forward-zone = [
        {
          name = ".";
          forward-addr = [
            # dns10.quad9.net
            "2620:fe::10#dns10.quad9.net"
            "2620:fe::fe:10#dns10.quad9.net"
            "9.9.9.10#dns10.quad9.net"
            "149.112.112.10#dns10.quad9.net"
            # fallback
            "8.8.8.8"
          ];
        }
      ];
    };
  };
}
