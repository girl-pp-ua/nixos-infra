{ ... }: {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    authKeyFile = "/tmp/tailscale_auth_key";
  };
}