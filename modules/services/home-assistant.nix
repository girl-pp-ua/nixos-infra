{
  config,
  pkgs,
  lib,
  libx,
  ...
}:
let
  cfg = config.polaris.services.home-assistant;
  cfg-svc = config.polaris.services;
  hass = config.services.home-assistant;
  idp = libx.idp {
    inherit (cfg-svc.kanidm) domain;
    inherit (cfg) client_id;
  };
in
{
  options.polaris.services.home-assistant = {
    enable = lib.mkEnableOption "home assistant";
    client_id = lib.mkOption {
      type = lib.types.str;
      default = "home-assistant";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "ass.lunya.cc";
    };
    intraDomain = lib.mkOption {
      type = lib.types.str;
      default = "home-assistant.polaris";
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 8123;
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      extraComponents = [
        "default_config"
        "met"
        "esphome"
        "radio_browser"
        # zigbee via the official HA dongles (ZBT-1 / ZBT-2)
        "zha"
        "homeassistant_sky_connect"
        "homeassistant_connect_zbt2"
      ];
      customComponents = [
        pkgs.home-assistant-custom-components.auth_oidc
      ];
      config = {
        homeassistant = {
          auth_providers = [ ];
        };
        default_config = { };
        http = {
          server_host = [
            "127.0.0.1"
            "::1"
          ];
          server_port = cfg.port;
          use_x_forwarded_for = true;
          trusted_proxies = config.polaris.trustedNetworks;
          ip_ban_enabled = true;
          login_attempts_threshold = 5;
        };
        auth_oidc = {
          inherit (cfg) client_id;
          client_secret = "!secret oidc_client_secret";
          discovery_url = idp.oidc_discovery;
          display_name = "Kanidm";
          id_token_signing_alg = "ES256";
          features = {
            automatic_person_creation = true;
            force_https = true;
          };
          roles = {
            user = "home-assistant.access@${cfg-svc.kanidm.domain}";
            admin = "home-assistant.admin@${cfg-svc.kanidm.domain}";
          };
        };
        # allow managing these from the ui
        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${hass.configDir}/.storage 0700 hass hass - -"
      "f ${hass.configDir}/.storage/onboarding 0600 hass hass - ${
        builtins.toJSON {
          version = 4;
          minor_version = 1;
          key = "onboarding";
          data.done = [
            "user"
            "core_config"
            "analytics"
            "integration"
          ];
        }
      }"
      "f ${hass.configDir}/automations.yaml 0644 hass hass - []"
      "f ${hass.configDir}/scenes.yaml 0644 hass hass - []"
      "f ${hass.configDir}/scripts.yaml 0644 hass hass - {}"
    ];

    # confgure caddy
    services.caddy.virtualHosts."http://${cfg.intraDomain}" = {
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };

    sops = {
      secrets."home-assistant/clientSecret" = { };
      templates."home-assistant.secrets.yaml" = {
        path = "${hass.configDir}/secrets.yaml";
        owner = "hass";
        group = "hass";
        mode = "0400";
        content = ''
          oidc_client_secret: "${config.sops.placeholder."home-assistant/clientSecret"}"
        '';
      };
    };
  };
}
