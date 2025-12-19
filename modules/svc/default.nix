{ ... }:
{
  imports = [
    # Base services
    ./caddy
    ./dns-server
    ./nextcloud
    ./paperless
    ./gatus
    ./projects
    ./tailscale.nix
    ./redlib.nix
    ./ntfy.nix
    ./kanidm.nix
    ./oauth2-proxy.nix
    ./garage.nix
    ./immich.nix
    ./supervisor-host.nix
    ./collabora.nix
  ];
}
