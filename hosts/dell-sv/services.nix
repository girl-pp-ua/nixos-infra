{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    oauth2_proxy.enable = true;
    dns-server.enable = true; # (for the .polaris zone)
    nextcloud.enable = true;
    paperless.enable = true;
    immich.enable = true;
    forgejo.enable = true;

    backup = {
      enable = true;
      repo = "/mnt/data/backups";
    };

    # experimental stuff:
    experimental = {
      gayming-nixos = {
        enable = true;
        vuinputd.enable = true;
      };
    };
  };
}
