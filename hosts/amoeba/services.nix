{ ... }:
{
  polaris.services = {

    caddy.enable = true;
    dns-server.enable = true; # (for the .polaris zone)

    bookorbit.enable = true;
    karakeep.enable = true;
    attic.enable = true;
    experimental.hydra.enable = true;
    monitoring.server.enable = true;

    legacy01.enable = true; # devlootbox
  };
}
