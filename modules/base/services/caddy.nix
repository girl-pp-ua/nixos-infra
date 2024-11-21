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
    extraConfig = ''
      (cors) {
        @origin{args.0} header Origin {args.0}
        header @origin{args.0} Access-Control-Allow-Origin "{args.0}"
        header @origin{args.0} Vary Origin
      }
    '';
  };
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 443 ];
  };
}