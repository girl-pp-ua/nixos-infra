{ ... }:
{
  imports = [
    # Base services
    ./caddy
    ./dns-server
    ./experimental
    ./gatus
    ./nextcloud
    ./backup.nix
    ./bookorbit.nix
    ./dashy.nix
    ./forgejo.nix
    ./home-assistant.nix
    ./garage.nix
    ./immich.nix
    ./karakeep
    ./kanidm.nix
    ./legacy01
    ./monitoring
    ./ntfy.nix
    ./oauth2-proxy.nix
    ./paperless.nix
    ./tailscale.nix
  ];
}
