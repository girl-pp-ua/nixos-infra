{ ... }:
{
  imports = [
    # Base services
    ./caddy
    ./dns-server
    ./nextcloud
    ./gatus
    ./projects
    ./supervisor-host.nix
    ./tailscale.nix
    ./redlib.nix
    ./ntfy.nix
    ./kanidm.nix
    ./oauth2-proxy.nix
    ./garage.nix
    ./immich.nix
    ./paperless.nix
  ];
}
