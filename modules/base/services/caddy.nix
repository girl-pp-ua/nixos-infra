{ ... }: {
  services.caddy ={
    enable = true;
    enableReload = true;
    adapter = "caddyfile";
    email = "prasol258@gmail.com";
    globalConfig = ''
      grace_period 30s
      skip_install_trust
      renew_interval 30m
    '';
  };
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 443 ];
  };
}