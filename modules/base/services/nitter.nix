{ config, pkgs, lib, ... }:
let
  cfg = config.cfg;
  crenentialsFile = pkgs.writeText "twitter-credentials.json" cfg.secrets.twitter.credentials;
in
{
  options = {
    cfg.services.nitter = {
      enable = lib.mkEnableOption "redlib";
      port = lib.mkOption {
        type = lib.types.int;
        default = 16017;
      };
      domain = lib.mkOption {
        type = lib.types.str;
        default = "redlib.girl.pp.ua";
      };
    };
  };
  config = lib.mkIf cfg.services.nitter.enable  {
    services.nitter = {
      enable = true;
      # package: https://github.com/zedeus/nitter ?
      server = {
        # title = "...";
        address = "127.0.0.1";
        port = cfg.services.nitter.port;
        hostname = cfg.services.nitter.domain;
      };
      preferences = {
        squareAvatars = true;
        replaceTwitter = cfg.services.nitter.domain;
        replaceReddit = cfg.services.redlib.domain;
        # proxyVideos = false; # (might be slow)
        muteVideos = true;
        hlsPlayback = true; # requires js
        infiniteScroll = true; # requires js
      };
    };

    systemd.services.nitter.environment = {
      "DISABLE_NGINX" = "true";
      "TWITTER_CREDENTIALS_FILE" = "${crenentialsFile}";
    };

    services.caddy.virtualHosts = {
      ${cfg.services.nitter.domain} = {
        extraConfig = ''
          import encode
          reverse_proxy localhost:${builtins.toString cfg.services.nitter.port}
        '';
      };
    };
  };
}