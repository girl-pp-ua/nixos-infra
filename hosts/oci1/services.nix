{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    caddy.plugins = {
      enable = true;
      webdav = true;

    };
    caddy.endpoints = {
      file-server.enable = true;
      webdav.enable = true;
      authtest.enable = true;
    };
    dns-server.enable = true;
    kanidm.enable = true;
    gatus.enable = true;
    garage.enable = true;
  };

  services.caddy.virtualHosts = {
    "status.girl.pp.ua".extraConfig = ''
      redir https://status.lunya.cc{uri} permanent
    '';
  };
}
