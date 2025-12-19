{ config, lib, ... }:
let
  cfg = config.nix-infra.svc.collabora;
in
{
  options.nix-infra.svc.collabora = {
    enable = lib.mkEnableOption "collabora office app";
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "collabora.nix-infra";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "office.girl.pp.ua";
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 9980;
    };
    allowHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        config.nix-infra.svc.nextcloud.domain
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.collabora-online = {
      enable = true;
      inherit (cfg) port;
      # aliasGroups = [
      #   {
      #     host = "https://cloud.girl.pp.ua:443";
      #     aliases = [ ];
      #   }
      # ];
      settings = {
        server_name = cfg.domain;
        ssl = {
          enable = false;
          termination = true;
        };
        net = {
          listen = "loopback";
          post_allow.host = [ "::1" ];
        };
        storage.wopi = {
          "@allow" = true;
          # XXX: might be incorrect for multiple hosts
          host = cfg.allowHosts;
        };
      };
    };

    services.caddy.virtualHosts."http://${cfg.intraDomain}" = {
      serverAliases = [ "http://${cfg.domain}" ];
      extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://[::1]:${toString cfg.port}
      '';
    };
    
    
  };
}
