{
  config,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.immich;
  idp = libx.idp {
    domain = config.polaris.services.kanidm.domain;
    inherit (cfg) client_id;
  };
in
{
  options.polaris.services.immich = {
    enable = lib.mkEnableOption "immich";
    port = lib.mkOption {
      type = lib.types.int;
      default = 2283;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "photos.girl.pp.ua";
    };
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "immich";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "immich.polaris";
    };
  };

  config = lib.mkIf cfg.enable {
    services.immich = {
      enable = true;
      host = "localhost";
      inherit (cfg) port;
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
        server.externalDomain = "https://${cfg.domain}";
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

    services.caddy.virtualHosts."http://${cfg.intraDomain}" = {
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode
        reverse_proxy http://localhost:${toString config.services.immich.port}
      '';
    };
  };
}
