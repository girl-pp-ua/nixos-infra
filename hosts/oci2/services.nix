{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    caddy.endpoints = {
      healthcheck.enable = true;
      proxies.enable = true; # rip cocoa
    };
    dns-server.enable = true;
    # redlib.enable = true;
    ntfy.enable = true;
    # projects.devlootbox.enable = true;
  };

  services.caddy.virtualHosts."redlib.girl.pp.ua".extraConfig = ''
    redir https://old.reddit.com{uri} temporary
  '';
}
