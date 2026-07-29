{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    caddy.endpoints = {
      proxies.enable = true; # rip cocoa
    };
    dns-server.enable = true;

    dashy.enable = true;

    experimental = {
      svn.enable = true;
    };
  };
}
