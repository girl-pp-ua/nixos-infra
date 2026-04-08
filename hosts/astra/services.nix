{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    caddy.endpoints = {
      proxies.enable = true; # rip cocoa
    };
    dns-server.enable = true;
  };
}
