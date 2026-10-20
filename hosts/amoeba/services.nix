{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    dns-server.enable = true; # (for the .polaris zone)

    bookorbit.enable = true;

    monitoring.server.enable = true;

    experimental.hydra.enable = true;
  };
}
