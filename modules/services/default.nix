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
    ./dashy.nix
    ./forgejo.nix
    ./garage.nix
    ./immich.nix
    ./kanidm.nix
    ./ntfy.nix
    ./oauth2-proxy.nix
    ./paperless.nix
    ./tailscale.nix
  ];
}
