{ config, lib, ... }:
let
  cfg = config.polaris.services.home-assistant;
  hass = config.services.home-assistant;
in
{
  options.polaris.services.home-assistant = {
    enable = lib.mkEnableOption "home assistant";
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
      ];
      config = {
        default_config = { };
        http = {
          server_host = [
            "127.0.0.1"
            "::1"
          ];
          server_port = cfg.port;
          use_x_forwarded_for = true;
          trusted_proxies = config.polaris.trustedNetworks;
        };
        # allow managing these from the ui
        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";
      };
    };

    systemd.tmpfiles.rules = [
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
  };
}
