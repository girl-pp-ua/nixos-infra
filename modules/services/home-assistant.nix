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
    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
    };
    matter = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 5580;
      };
      threadRadio = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "serial device of a radio running openthread rcp firmware";
      };
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
        "ibeacon"
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
        # ikea bilresa
        (pkgs.buildHomeAssistantComponent rec {
          owner = "Vituhlos";
          domain = "ikea_bilresa";
          version = "0.6.1";
          src = pkgs.fetchFromGitHub {
            inherit owner;
            repo = "ha-ikea-bilresa";
            tag = "v${version}";
            hash = "sha256-NEZrbT4AJQnp3QD/nYor0YA+hE8CdIUu+VKxXExTbzQ=";
          };
        })
      ];
      config = {
        homeassistant = {
          auth_providers = [ ]; # nuke passwd
          time_zone = lib.mkForce null;
        };
        default_config = { };
        prometheus.requires_auth = true;
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

    systemd.services.home-assistant.path = [
      pkgs.openssl
    ];
    systemd.services.home-assistant.preStart = lib.mkAfter ''
      # set default external_url and locale
      #
      f=${hass.configDir}/.storage/core.config
      if [ -f "$f" ]; then
        ${lib.getExe pkgs.jq} --arg url "https://${cfg.domain}" '
          .data.external_url = $url
          | .data.language = "en-GB"
          | .data.unit_system_v2 = "metric"
          | .data.currency = "EUR"
        ' "$f" > "$f.tmp"
        chmod 600 "$f.tmp"
        mv "$f.tmp" "$f"
      fi

      # seed a long-lived access token for prometheus into the auth store
      #
      f=${hass.configDir}/.storage/auth
      id=prometheus
      [ -f "$f" ] || echo '{"version":1,"minor_version":1,"key":"auth","data":{"users":[],"groups":[],"credentials":[],"refresh_tokens":[]}}' > "$f"
      key=$(cat ${config.sops.secrets."home-assistant/metricsJwtKey".path})
      ${lib.getExe pkgs.jq} --arg id "$id" --arg key "$key" --arg token "$(openssl rand -hex 64)" --arg now "$(date -Iseconds)" '
        .data.users |= map(select(.id != $id)) + [{
          id: $id, name: "Prometheus", group_ids: ["system-read-only"],
          is_owner: false, is_active: true, system_generated: true, local_only: false
        }]
        | .data.refresh_tokens |= map(select(.id != $id)) + [{
          id: $id, user_id: $id, client_id: null, client_name: "Prometheus", client_icon: null,
          token_type: "long_lived_access_token", created_at: $now, access_token_expiration: 315360000,
          token: $token, jwt_key: $key, last_used_at: null, last_used_ip: null, expire_at: null, credential_id: null
        }]
      ' "$f" > "$f.tmp"
      chmod 600 "$f.tmp"
      mv "$f.tmp" "$f"

      # default every user's profile to en-GB with a 24h clock
      # (only fields the user hasn't picked themselves; the frontend applies each field separately)
      for id in $(${lib.getExe pkgs.jq} -r '.data.users[] | select((.system_generated | not) and .is_active) | .id' "$f"); do
        u=${hass.configDir}/.storage/frontend.user_data_$id
        [ -f "$u" ] || echo "{\"version\":1,\"minor_version\":1,\"key\":\"frontend.user_data_$id\",\"data\":{}}" > "$u"
        ${lib.getExe pkgs.jq} '
          .data.language = ((.data.language // {})
            | if (.language // "") == "" then .language = "en-GB" else . end
            | if (.time_format // "language") == "language" then .time_format = "24" else . end)
        ' "$u" > "$u.tmp"
        chmod 600 "$u.tmp"
        mv "$u.tmp" "$u"
      done
    '';

    # required by the matter integration (ws://localhost:<matter.port>/ws)
    services.matterjs-server = {
      enable = true;
      port = cfg.matter.port;
    };

    # thread border router, required by the otbr integration (http://127.0.0.1:8081)
    services.openthread-border-router = lib.mkIf (cfg.matter.threadRadio != null) {
      enable = true;
      backboneInterfaces = [
        cfg.lanInterface
      ];
      radio = {
        device = cfg.matter.threadRadio;
        baudRate = 460800; # (zbt-1 openthread rcp firmware)
        flowControl = true;
      };
    };

    # route between lan and thread mesh
    networking.firewall.extraForwardRules =
      let
        wpan = config.services.openthread-border-router.interfaceName;
      in
      lib.mkIf (cfg.matter.threadRadio != null) ''
        iifname "${cfg.lanInterface}" oifname "${wpan}" accept
        iifname "${wpan}" oifname "${cfg.lanInterface}" accept
      '';

    # let thread devices reach the matter controller
    networking.firewall.interfaces.${config.services.openthread-border-router.interfaceName} =
      lib.mkIf (cfg.matter.threadRadio != null)
        {
          allowedUDPPortRanges = [
            {
              from = 1024;
              to = 65535;
            }
          ];
        };

    networking.firewall.interfaces.${cfg.lanInterface} = {
      allowedUDPPorts = [
        # mdns, used for local discovery (hue, cast, homekit, matter, etc.)
        5353
      ];
      allowedTCPPorts = [
        # direct lan accesss
        cfg.port
      ];
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

    # metricsToken: a jwt signed with metricsJwtKey, with iss = "prometheus"
    polaris.services.monitoring.exports.home-assistant = {
      inherit (cfg) port;
      path = "/api/prometheus";
      bearerTokenSecret = "home-assistant/metricsToken";
    };

    sops = {
      secrets."home-assistant/clientSecret" = { };
      secrets."home-assistant/metricsJwtKey" = {
        owner = "hass";
        restartUnits = [ "home-assistant.service" ];
      };
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
