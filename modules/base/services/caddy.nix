{ ... }: {
  services.caddy ={
    enable = true;
    enableReload = true;
    adapter = "caddyfile";
    email = "prasol258@gmail.com";
    globalConfig = ''
      grace_period 30s
      skip_install_trust
      key_type ed25519
      renew_interval 30m
    '';
  };
}