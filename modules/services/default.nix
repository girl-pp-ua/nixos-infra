{ ... }:
{
  imports = [
    # Base services
    ./caddy
    ./dns-server
    ./nextcloud
    ./gatus
    ./projects
    ./tailscale.nix
    ./redlib.nix
    ./ntfy.nix
    ./kanidm.nix
    ./oauth2-proxy.nix
    ./garage.nix
    ./immich.nix
    ./paperless.nix
    ./backup.nix
    ./experimental/supervisor-host.nix
    ./experimental/gayming.nix
    ./experimental/docker.nix
  ];
}
