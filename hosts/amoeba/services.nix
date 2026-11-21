{ ... }:
{
  polaris.services = {

    caddy.enable = true;
    dns-server.enable = true; # (for the .polaris zone)

    bookorbit.enable = true;
    karakeep.enable = true;
    attic.enable = true;
    hydra = {
      enable = true;
      builder = {
        enable = true;
        maxJobs = 8;
        speedFactor = 20;
      };
    };
    monitoring.server.enable = true;

    legacy01.enable = true; # devlootbox
  };
}
