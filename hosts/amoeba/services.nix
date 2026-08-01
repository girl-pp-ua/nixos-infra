{ ... }:
{
  polaris.services = {
    caddy.enable = true;
    dns-server.enable = true; # (for the .polaris zone)

    experimental.hydra.enable = true;
  };
}
