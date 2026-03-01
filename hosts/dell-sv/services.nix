{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    oauth2_proxy.enable = true;
    dns-server.enable = true; # (for the .polaris zone)
    nextcloud.enable = true;
    paperless.enable = true;
    immich.enable = true;

    backup = {
      enable = true;
      repo = "/mnt/data/backups";
    };

    # TODO: fix
    # gayming.enable = true;

    # TODO: fix
    # supervisor-host = {
    #   enable = true;
    #   gpuPassthrough = true;
    # };
  };
}
