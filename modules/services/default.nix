{ ... }:
{
  imports = [
    # Base services
    ./caddy
    ./dns-server
    ./nextcloud
    ./gatus
    ./projects
    ./openssh.nix
    ./sshguard.nix
    ./tailscale.nix
    ./redlib.nix
    ./ntfy.nix
    ./kanidm.nix
    ./oauth2-proxy.nix
    ./garage.nix
    ./hydroxide
  ];
}
