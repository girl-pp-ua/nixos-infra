{ ... }: let
  ntfySubdomain = "ntfy.girl.pp.ua";
  port = 16002;
in {
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://${ntfySubdomain}";
      upstream-base-url = "https://ntfy.sh";
      listen-http = "127.0.0.1:${toString port}";
      behind-proxy = true;
      # enable-signup = true;
      # enable-login = true;
      enable-reservations = true;
    };
  };

  services.caddy.virtualHosts = {
    ${ntfySubdomain} = {
      extraConfig = ''
        reverse_proxy localhost:${toString port}
      '';
    };
  };
}