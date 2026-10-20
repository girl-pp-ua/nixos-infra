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
    ./bookorbit.nix
    ./dashy.nix
    ./forgejo.nix
    ./home-assistant.nix
    ./garage.nix
    ./immich.nix
    ./kanidm.nix
    ./monitoring
    ./ntfy.nix
    ./oauth2-proxy.nix
    ./paperless.nix
    ./tailscale.nix
  ];
}
