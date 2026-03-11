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

  services.caddy.virtualHosts = {
    "redlib.girl.pp.ua".extraConfig = "redir https://old.reddit.com{uri} temporary";
    "photos.girl.pp.ua".extraConfig = "redir https://photos.lunya.cc{uri} permanent";
    "paperless.girl.pp.ua".extraConfig = "redir https://paperless.lunya.cc{uri} permanent";
    "cloud.girl.pp.ua".extraConfig = "redir https://cloud.lunya.cc{uri} permanent";
  };
}
