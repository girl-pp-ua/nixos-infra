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
    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 16131;
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      extraComponents = [
        "default_config"
        "prometheus"
        "met"
        "esphome"
        "radio_browser"
        # zigbee via the official HA dongles (ZBT-1 / ZBT-2)
        "zha"
        "homeassistant_sky_connect"
        "homeassistant_connect_zbt2"
        # matter / thread
        "matter"
        "thread"
        "otbr"
        # generic
        "mqtt"
        "homekit_controller"
        "upnp"
        "dlna_dmr"
        # lights
        "hue"
        "tradfri"
        "lifx"
        "nanoleaf"
        "wiz"
        "wled"
        "yeelight"
        "govee_light_local"
        # plugs/switches/sensors
        "tplink"
        "shelly"
        "tuya"
        "switchbot"
        "broadlink"
        "xiaomi_miio"
        "xiaomi_ble"
        # media
        "cast"
        "spotify"
        "apple_tv"
        "androidtv_remote"
        "samsungtv"
        "webostv"
        # appliances/climate/misc
        "smartthings"
        "ipp"
        "brother"
        # google
        "google_assistant"
        "google_assistant_sdk"
        "nest"
        "google"
        "google_tasks"
        "google_health"
        "google_drive"
        "google_photos"
        "google_mail"
        "google_translate"
        "google_generative_ai_conversation"
        "youtube"
        # ai
        "anthropic"
        "mcp_server"
        "mcp"
      ];
      # faster zlib for aiohttp
      extraPackages =
        ps: with ps; [
          zlib-ng
          isal
        ];
      customComponents = [
        pkgs.home-assistant-custom-components.auth_oidc
        pkgs.home-assistant-custom-components.scene_presets
      ];
      config = {
        homeassistant = {
          auth_providers = [ ];
          time_zone = lib.mkForce null;
        };
        default_config = { };
        # only reachable through the collector port below
        prometheus.requires_auth = false;
        # XXX: http settings wont actually be respected, except first launch
        # womp womp
        http = {
          server_host = [
            "0.0.0.0"
            "::"
          ];
          server_port = cfg.port;
          use_x_forwarded_for = true;
          trusted_proxies = [
            "127.0.0.1"
            "::1"
          ]
          ++ lib.concatMap (
            host:
            lib.optionals (host ? internal) [
              host.internal.ipv4
              host.internal.ipv6
            ]
          ) (lib.attrValues config.polaris.hosts);
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

    # set external_url in the stored core config instead of yaml
    # (prevent lock on the whole "general" settings page in the ui)
    systemd.services.home-assistant.preStart = lib.mkAfter ''
      f=${hass.configDir}/.storage/core.config
      if [ -f "$f" ]; then
        ${lib.getExe pkgs.jq} --arg url "https://${cfg.domain}" \
          '.data.external_url = $url' "$f" > "$f.tmp"
        chmod 600 "$f.tmp"
        mv "$f.tmp" "$f"
      fi
    '';

    # required by the matter integration (ws://localhost:5580/ws)
    services.matter-server.enable = true;

    # mdns, used for local discovery (hue, cast, homekit, matter, etc.)
    networking.firewall.allowedUDPPorts = [ 5353 ];

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
      listenAddresses = config.polaris.services.caddy.internalListenAddresses;
      serverAliases = [
        "http://${cfg.domain}"
      ];
      extraConfig = ''
        import encode
        respond /api/prometheus* 404
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };

    # direct lan access, on the same port hass advertises over mdns
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    services.caddy.virtualHosts."http://:${toString cfg.metricsPort}".extraConfig = ''
      handle /api/prometheus {
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      }
      respond 403
    '';
    polaris.services.monitoring.exports.home-assistant = {
      port = cfg.metricsPort;
      path = "/api/prometheus";
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
