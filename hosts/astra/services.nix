{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    caddy.endpoints = {
      proxies.enable = true; # rip cocoa
    };
    dns-server.enable = true;

    dashy.enable = true;

    hydra.builder = {
      enable = true;
      maxJobs = 8;
      speedFactor = 10;
    };

    experimental = {
      svn.enable = true;
    };
  };
}
