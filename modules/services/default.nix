{ ... }:
{
  imports = [
    # Base services
    ./caddy
    ./dns-server
    ./experimental
    ./gatus
    ./nextcloud
    ./projects
    ./backup.nix
    ./forgejo.nix
    ./garage.nix
    ./immich.nix
    ./kanidm.nix
    ./ntfy.nix
    ./oauth2-proxy.nix
    ./paperless.nix
    ./redlib.nix
    ./tailscale.nix
  ];
}
