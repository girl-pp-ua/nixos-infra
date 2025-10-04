{
  config,
  lib,
  libx,
  ...
}:
let
  inherit (config) cfg;
  idp = libx.idp {
    domain = cfg.services.kanidm.domain;
    client_id = "immich";
  };
in
{
  options.cfg.services.immich = {
    enable = lib.mkEnableOption "immich";
    port = lib.mkOption {
      type = lib.types.int;
      default = 2283;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "photos.girl.pp.ua";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "immich.nix-infra";
    };
  };

  config = lib.mkIf cfg.services.immich.enable {
    services.immich = {
      enable = true;
      host = "localhost";
      inherit (cfg.services.immich) port;
      accelerationDevices = null; # (allow all)
      database = {
        enableVectors = false;
        enableVectorChord = true;
      };
      environment = {
        IMMICH_CONFIG_FILE = config.sops.templates."immich.json".path;
      };
    };

    sops.secrets."immich/clientSecret" = { };
    sops.templates."immich.json" = {
      mode = "0400";
      owner = config.services.immich.user;
      group = config.services.immich.group;
      content = builtins.toJSON {
        server.externalDomain = "https://${cfg.services.immich.domain}";
        newVersionCheck.enabled = false;
        passwordLogin.enabled = false;
        oauth = {
          enabled = true;
          issuerUrl = idp.oidc_discovery;
          clientId = "immich";
          clientSecret = config.sops.placeholder."immich/clientSecret";
          signingAlgorithm = "ES256";
          # profileSigningAlgorithm = "ES256";
        };
      };
    };

    services.caddy.virtualHosts."http://${cfg.services.immich.intraDomain}" = {
      serverAliases = [
        "http://${cfg.services.immich.domain}"
      ];
      extraConfig = ''
        import encode
        import norobot
        reverse_proxy http://localhost:${toString config.services.immich.port}
      '';
    };
  };
}
