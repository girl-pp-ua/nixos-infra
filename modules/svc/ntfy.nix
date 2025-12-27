{ config, lib, ... }:
let
  cfg = config.nix-infra.svc.ntfy;
in
{
  options.nix-infra.svc.ntfy = {
    enable = lib.mkEnableOption "ntfy-sh";
    port = lib.mkOption {
      type = lib.types.int;
      default = 16002;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "ntfy.girl.pp.ua";
    };
  };
  config = lib.mkIf cfg.enable {
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${cfg.domain}";
        upstream-base-url = "https://ntfy.sh";
        listen-http = "127.0.0.1:${toString cfg.port}";
        behind-proxy = true;
        # enable-signup = true;
        # enable-login = true;
        enable-reservations = true;
      };
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        import encode
        import norobot
        handle_path /docs/* {
          redir https://docs.ntfy.sh{path} permanent
        }
        reverse_proxy localhost:${toString cfg.port}
      '';
    };
  };
}
